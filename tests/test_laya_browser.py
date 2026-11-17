"""Exercise the launcher's file/process boundaries without loading models."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

FILE = Path(__file__).resolve().parents[1] / 'reComputer/scripts/laya-browser/launch.py'
spec = importlib.util.spec_from_file_location('laya_launcher', FILE)
launch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launch)


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / 'home with spaces'

    def tearDown(self):
        self.temp.cleanup()

    def test_existing_private_project_cannot_be_adopted(self):
        self.root.mkdir()
        saved = self.root / 'profile'
        saved.write_text('private')
        with self.assertRaisesRegex(RuntimeError, 'new or empty'):
            with launch.lock_home(self.root):
                pass
        self.assertEqual(saved.read_text(), 'private')

    def test_clean_retains_persistent_data(self):
        with launch.lock_home(self.root):
            saved = self.root / 'persistent'
            saved.mkdir()
            (saved / 'scene.excalidraw').write_text('keep')
        with patch.object(launch, 'runtime_home', return_value=self.root), patch.object(launch, 'host_check'), \
                patch.object(launch, 'containers', return_value=[]):
            self.assertEqual(launch.main(['clean']), 0)
        self.assertEqual((saved / 'scene.excalidraw').read_text(), 'keep')

    def test_compose_is_private_and_uses_host_user_and_persistent_volume(self):
        service = launch.compose_config(self.root, 'repo@sha256:' + 'a'*64, ':0')['services']['agent']
        self.assertEqual(service['user'], f'{os.getuid()}:{os.getgid()}')
        self.assertNotIn('ports', service)
        self.assertNotIn('network_mode', service)
        self.assertNotIn('privileged', service)
        self.assertTrue(service['read_only'])
        self.assertIn({'type':'bind', 'source':str(self.root/'persistent'), 'target':'/data', 'read_only':False}, service['volumes'])

    def test_wrong_image_is_rejected_before_container_creation(self):
        value = {'image':'example/image:v1','image_id':'sha256:'+'a'*64}
        for arch, identity in [('amd64', value['image_id']), ('arm64', 'sha256:'+'b'*64)]:
            with patch.object(launch, 'output', return_value=json.dumps([{'Architecture':arch,'Os':'linux','Id':identity}])):
                with self.assertRaisesRegex(RuntimeError, 'architecture/content'):
                    launch.ensure_image(value)

    def test_loaded_archive_without_registry_digest_uses_exact_local_image_id(self):
        ident = 'sha256:' + 'a'*64
        value = {'image':'example/image:v1','image_id':ident,'digest':'sha256:'+'b'*64}
        def inspect(*args):
            if '@' in args[-1]:
                raise subprocess.CalledProcessError(1, args)
            return json.dumps([{'Architecture':'arm64','Os':'linux','Id':ident}])
        with patch.object(launch, 'output', side_effect=inspect), patch.object(launch.subprocess, 'run') as pull:
            self.assertEqual(launch.ensure_image(value), ident)
        pull.assert_not_called()

    def test_foreign_container_is_never_stopped(self):
        foreign = {'Config':{'Labels':{launch.LABEL:'laya-browser','io.seeed.runtime-home':'/other'}}}
        with patch.object(launch, 'output', side_effect=['container-id', json.dumps([foreign])]):
            with self.assertRaisesRegex(RuntimeError, 'Another runtime'):
                launch.containers(self.root)

    def test_status_does_not_initialize_or_load_models(self):
        with patch.object(launch, 'runtime_home', return_value=self.root), patch.object(launch, 'host_check'), \
                patch.object(launch, 'containers', return_value=[]), patch.object(launch, 'start') as start:
            self.assertEqual(launch.main(['status']), 0)
        start.assert_not_called()
        self.assertFalse(self.root.exists())


if __name__ == '__main__':
    unittest.main()
