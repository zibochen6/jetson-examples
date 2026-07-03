import cv2
import os
import time
import argparse
import sys
from ultralytics import YOLO

DISPLAY_W, DISPLAY_H = 640, 480

def has_display():
    display_env = os.environ.get("DISPLAY")
    if not display_env:
        return False
    return True

def main():
    parser = argparse.ArgumentParser(description="YOLO26 Realtime Detection")
    parser.add_argument("--source", type=str, default="0", help="0 for camera, or video file path")
    parser.add_argument("--model", type=str, default="yolo26n.pt", help="model path")
    parser.add_argument("--conf", type=float, default=0.5, help="confidence threshold")
    parser.add_argument("--save", type=str, default=None, help="save output video to file")
    parser.add_argument("--imgsz", type=int, default=640, help="inference size")
    args = parser.parse_args()

    source = int(args.source) if args.source.isdigit() else args.source

    model = YOLO(args.model, task="detect")
    cap = cv2.VideoCapture(source)

    if not cap.isOpened():
        print(f"ERROR: cannot open source {args.source}")
        sys.exit(1)

    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS) or 30

    use_display = has_display()

    if use_display:
        print("检测到显示器，实时显示模式")
        save_path = args.save
    else:
        print("未检测到显示器，自动保存到本地")
        save_path = args.save if args.save else "/output/result.mp4"
        os.makedirs(os.path.dirname(save_path), exist_ok=True)

    writer = None
    if save_path:
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        writer = cv2.VideoWriter(save_path, fourcc, fps, (DISPLAY_W, DISPLAY_H))

    print(f"Source: {args.source} ({w}x{h} @ {fps:.1f}fps)")
    print(f"Display: {DISPLAY_W}x{DISPLAY_H}")
    print(f"Model:  {args.model}")
    print(f"Conf:   {args.conf}")
    print(f"Show:   {use_display}")
    print(f"Save:   {save_path if save_path else 'None'}")
    print("Press q to quit" if use_display else "Processing...")

    frame_count = 0
    total_time = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            print("End of video or read error")
            break

        t0 = time.perf_counter()
        results = model.predict(source=frame, imgsz=args.imgsz, conf=args.conf, verbose=False)
        dt = time.perf_counter() - t0
        total_time += dt
        frame_count += 1
        fps_actual = 1.0 / dt if dt > 0 else 0

        annotated = results[0].plot()
        display = cv2.resize(annotated, (DISPLAY_W, DISPLAY_H))
        cv2.putText(display, f"FPS: {fps_actual:.1f}  Frame: {frame_count}",
                    (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1, cv2.LINE_AA)

        if use_display:
            cv2.imshow("YOLO26 Detection", display)

        if writer:
            writer.write(display)

        if use_display and cv2.waitKey(1) & 0xFF == ord("q"):
            break

    avg_fps = frame_count / total_time if total_time > 0 else 0
    print(f"\nDone: {frame_count} frames, avg {avg_fps:.1f} FPS ({total_time/frame_count*1000:.1f}ms/frame)")
    if save_path:
        print(f"Result saved to: {save_path}")

    cap.release()
    if writer:
        writer.release()
    if use_display:
        cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
