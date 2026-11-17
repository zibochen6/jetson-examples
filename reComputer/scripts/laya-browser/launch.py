#!/usr/bin/env python3
"""A fixed, all-in-one ARM64 Docker release with user-owned persistent data."""
import argparse
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PROJECT = 'jetson_examples_laya'
LABEL = 'io.seeed.jetson-example'
IDENTITY = {'example': 'laya-browser', 'layout': 1}


def output(*args):
    return subprocess.check_output(list(args), text=True, stderr=subprocess.STDOUT).strip()


def release():
    value = json.loads((HERE / 'release.json').read_text())
    if not re.fullmatch(r'sha256:[a-f0-9]{64}', value.get('image_id') or ''):
        raise RuntimeError('This example has no verified image yet. Use a release with a completed image manifest.')
    if value.get('digest') and not re.fullmatch(r'sha256:[a-f0-9]{64}', value['digest']):
        raise RuntimeError('Invalid image digest in release manifest')
    return value


def runtime_home():
    path = Path(os.environ.get('JETSON_LAYA_HOME', str(Path.home() / 'reComputer/laya-browser'))).expanduser()
    if not path.is_absolute():
        raise RuntimeError('JETSON_LAYA_HOME must be an absolute path')
    path = path.resolve()
    if path in (Path(path.anchor), Path.home().resolve(), HERE) or HERE in path.parents:
        raise RuntimeError('Use a separate runtime directory outside the installed package')
    return path


def host_check():
    if platform.system() != 'Linux' or platform.machine() != 'aarch64':
        raise RuntimeError('Run on the Jetson Orin NX 16GB, not a Mac or x86 host.')
    model = Path('/proc/device-tree/model').read_text().replace('\0', '')
    l4t = Path('/etc/nv_tegra_release').read_text()
    memory = Path('/proc/meminfo').read_text()
    if 'Orin NX' not in model or 'REVISION: 4.3' not in l4t or '# R36' not in l4t:
        raise RuntimeError('This release is validated only for Orin NX 16GB / L4T 36.4.3.')
    if int(re.search(r'MemTotal:\s+(\d+)', memory)[1]) < 14 * 1024 * 1024:
        raise RuntimeError('This two-model release requires the 16GB Orin NX.')
    if os.geteuid() == 0:
        raise RuntimeError('Run as the logged-in desktop user without sudo; Docker access is required.')
    runtimes = json.loads(output('docker', 'info', '--format', '{{json .Runtimes}}'))
    if 'nvidia' not in runtimes:
        raise RuntimeError('NVIDIA Container Runtime is missing. Prepare it before running this example.')
    output('docker', 'compose', 'version')
    print('Host ready: Orin NX 16GB / L4T 36.4.3 / Docker + NVIDIA Runtime.', flush=True)


def desktop():
    display = os.environ.get('DISPLAY', ':0')
    if not re.fullmatch(r':\d+(?:\.\d+)?', display):
        raise RuntimeError('Use the local X11 desktop DISPLAY, for example :0; SSH X11 forwarding is unsupported.')
    if os.environ.get('XDG_SESSION_TYPE') == 'wayland':
        raise RuntimeError('Log into an X11 desktop before starting this example.')
    number = display[1:].split('.')[0]
    if not Path('/tmp/.X11-unix', 'X' + number).exists():
        raise RuntimeError('No active X11 desktop socket. Log into the Jetson desktop first.')
    candidates = [Path(os.environ['XAUTHORITY'])] if os.environ.get('XAUTHORITY') else [
        Path(f'/run/user/{os.getuid()}/gdm/Xauthority'), Path.home() / '.Xauthority']
    authority = next((p for p in candidates if p.is_file() and os.access(p, os.R_OK)), None)
    if not authority:
        raise RuntimeError('Cannot read the desktop Xauthority. Run from the logged-in desktop terminal.')
    if not shutil.which('xauth'):
        raise RuntimeError('Install the host xauth utility before running the desktop example.')
    cookies = output('xauth', '-f', str(authority), 'nlist', display)
    if not cookies:
        raise RuntimeError('No X11 authorization cookie matches DISPLAY.')
    return display, '\n'.join('ffff' + line[4:] for line in cookies.splitlines()) + '\n'


@contextmanager
def lock_home(root, create=True):
    cache = Path.home() / '.cache/jetson-examples'
    cache.mkdir(parents=True, exist_ok=True)
    with (cache / 'laya-browser.lock').open('a') as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('Another Laya start/stop is in progress') from None
        if not root.exists():
            if not create:
                yield False
                return
            root.mkdir(parents=True, mode=0o700)
        marker = root / '.jetson-example.json'
        if not marker.exists():
            if not create:
                raise RuntimeError('This directory is not owned by the Laya example')
            if any(root.iterdir()):
                raise RuntimeError('JETSON_LAYA_HOME must be new or empty; existing deployments are not adopted.')
            marker.write_text(json.dumps(IDENTITY) + '\n')
        elif json.loads(marker.read_text()) != IDENTITY:
            raise RuntimeError('Runtime directory belongs to another example/layout')
        yield True


def containers(root):
    ids = output('docker', 'ps', '-aq', '--filter', f'label=com.docker.compose.project={PROJECT}').split()
    found = json.loads(output('docker', 'inspect', *ids)) if ids else []
    for item in found:
        labels = item['Config'].get('Labels') or {}
        if labels.get(LABEL) != 'laya-browser' or labels.get('io.seeed.runtime-home') != str(root):
            raise RuntimeError('Another runtime owns the Laya Compose project. It was not changed.')
    return found


def image_ref(value):
    return value['image'].rsplit(':', 1)[0] + '@' + value['digest'] if value.get('digest') else value['image']


def ensure_image(value):
    ref = image_ref(value)
    data = None
    # docker save/load retains image IDs/tags but may not retain registry digests.
    for candidate in dict.fromkeys((ref, value['image'], value['image_id'])):
        try:
            data = json.loads(output('docker', 'image', 'inspect', candidate))[0]
            break
        except subprocess.CalledProcessError:
            pass
    if data is None:
        subprocess.run(['docker', 'pull', ref], check=True)
        data = json.loads(output('docker', 'image', 'inspect', ref))[0]
    if data['Architecture'] != 'arm64' or data['Os'] != 'linux' or data['Id'] != value['image_id']:
        raise RuntimeError('Image architecture/content differs from the tested release. No container was started.')
    return data['Id']


def compose_config(root, image, display):
    def bind(source, target, readonly=False):
        return {'type': 'bind', 'source': str(source), 'target': target, 'read_only': readonly}
    return {'services': {'agent': {
        'image': image, 'pull_policy': 'never', 'runtime': 'nvidia', 'user': f'{os.getuid()}:{os.getgid()}',
        'group_add': [str(group) for group in sorted(set(os.getgroups()))],
        'read_only': True, 'shm_size': '1gb', 'stop_grace_period': '60s',
        'labels': {LABEL: 'laya-browser', 'io.seeed.runtime-home': str(root)},
        'environment': {'DISPLAY': display, 'XAUTHORITY': '/run/jetson/Xauthority'},
        'tmpfs': ['/tmp:size=512m,mode=1777'],
        'volumes': [bind(root / 'persistent', '/data'), bind(root / 'Xauthority', '/run/jetson/Xauthority', True),
                    bind('/tmp/.X11-unix', '/tmp/.X11-unix', True), bind('/proc/device-tree/model', '/run/jetson/model', True)]
    }}}


def compose_command(root, *args):
    return ['docker', 'compose', '--project-directory', str(root), '-f', str(root / 'compose.json'), '-p', PROJECT, *args]


def compose(root, *args, capture=False):
    command = compose_command(root, *args)
    if capture:
        return output(*command)
    return subprocess.run(command, check=True).returncode


def start(root, value):
    display, cookies = desktop()
    existing = containers(root)
    if existing and any(c['Image'] != value['image_id'] for c in existing):
        raise RuntimeError('A different release is installed. Stop it with reComputer clean laya-browser before upgrading.')
    if not existing and shutil.disk_usage(root).free < value['required_free_gib'] * 1024**3:
        # An imported/pulled full image no longer needs room to download and unpack again.
        try:
            output('docker', 'image', 'inspect', image_ref(value))
        except subprocess.CalledProcessError:
            raise RuntimeError(f'First image pull needs at least {value["required_free_gib"]} GiB free disk space.') from None
    ref = ensure_image(value)
    config = compose_config(root, ref, display)
    previous = root / 'compose.json'
    if any(c['State']['Running'] for c in existing):
        if not previous.is_file() or json.loads(previous.read_text()) != config:
            raise RuntimeError('The running container uses different desktop/settings. Finish tasks and clean this case before changing settings.')
    (root / 'persistent').mkdir(exist_ok=True, mode=0o700)
    auth = root / 'Xauthority'
    auth.touch(mode=0o600, exist_ok=True)
    auth.chmod(0o600)
    subprocess.run(['xauth', '-f', str(auth), 'nmerge', '-'], input=cookies, text=True, check=True)
    (root / 'compose.json').write_text(json.dumps(config, indent=2) + '\n')
    print('Loading the bundled models. First image download and model loading are outside task timing.', flush=True)
    compose(root, 'up', '-d', '--wait', '--wait-timeout', '600')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', nargs='?', default='flights', choices=['flights', 'whiteboard', 'check', 'status', 'clean'])
    args = parser.parse_args(argv)
    root = runtime_home()
    host_check()
    if args.action == 'check':
        desktop()
        value = release()
        print('Desktop ready. Fixed image:', image_ref(value))
        print('No image was pulled, no model was loaded, and no task was submitted.')
        return 0
    if args.action == 'status':
        found = containers(root)
        if not found:
            print('STOPPED. Persistent data:', root / 'persistent')
            return 0
        print(json.dumps([{k: c.get(k) for k in ('Name', 'Image', 'State')} for c in found], indent=2))
        if found[0]['State']['Running']:
            compose(root, 'exec', '-T', 'agent', 'jetson-browser', 'status')
        return 0
    with lock_home(root, create=args.action != 'clean') as present:
        if not present:
            print('No deployment exists; nothing was stopped.')
            return 0
        if args.action == 'clean':
            found = containers(root)
            if found:
                if not (root / 'compose.json').is_file():
                    raise RuntimeError('Owned containers exist but compose.json is missing. Restore the file before cleanup.')
                compose(root, 'down', '--timeout', '60')
            print('Example containers stopped/removed. Image, canvas, models and task records retained.')
            return 0
        start(root, release())
    options = [] if sys.stdin.isatty() and sys.stdout.isatty() else ['-T']
    # Let Docker own the terminal so Ctrl+C reaches the in-container task loop.
    # A waiting Python parent would also receive SIGINT and could kill the client.
    command = compose_command(root, 'exec', *options, 'agent', 'python', '/opt/jetson-browser/docker/runtime.py', args.action)
    os.execvp(command[0], command)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print('\nTerminal disconnected. Inspect status before resuming; no task is replayed.')
        sys.exit(130)
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError) as error:
        print('Laya Browser: ' + str(error), file=sys.stderr)
        sys.exit(1)
