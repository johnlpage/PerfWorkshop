import time  
from flask import request  
from gunicorn.app.base import BaseApplication  
  
  
def line_stream(chunk_size=64 * 1024):  
    """Read the request stream in chunks and yield complete lines."""  
    buffer = ""  
    bytes_read = 0  
    content_length = request.content_length  
    start_time = time.time()  
  
    while True:  
        chunk = request.stream.read(chunk_size)  
        if not chunk:  
            break  
        bytes_read += len(chunk)  
        buffer += chunk.decode("utf-8")  
        while "\n" in buffer:  
            line, buffer = buffer.split("\n", 1)  
            line = line.strip()  
            if line:  
                yield line  
    # Don't forget the last line if no trailing newline  
    buffer = buffer.strip()  
    if buffer:  
        yield buffer  
  
  
def progress(count, start_time, content_length, bytes_read, logger, every=1000):  
    """Call in your loop; logs progress every N docs."""  
    if count % every != 0:  
        return  
    elapsed = time.time() - start_time  
    rate = count / elapsed if elapsed > 0 else 0  
    msg = f"Inserted {count} docs ({rate:.0f} docs/sec)"  
    if content_length and bytes_read:  
        pct = bytes_read / content_length  
        remaining = (elapsed / pct - elapsed) if pct > 0 else 0  
        msg += f" | {pct:.1%} done, ~{remaining:.0f}s remaining"  
    logger.info(msg)  
  
  
class GunicornApp(BaseApplication):  
    def __init__(self, app, options=None):  
        self.application = app  
        self.options = options or {}  
        super().__init__()  
  
    def load_config(self):  
        for key, value in self.options.items():  
            self.cfg.set(key, value)  
  
    def load(self):  
        return self.application  
