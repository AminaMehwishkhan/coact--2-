# Full CoAct: real MuJoCo physics, real camera rendering, OpenVINO scoring.
#
# The whole point of this image is headless GPU-less rendering. MuJoCo renders
# the two agent cameras through EGL, which needs the EGL and GL runtime
# libraries present even though there is no display and no GPU — Mesa falls
# back to software rendering. Without libegl1 the app still boots but reports
# physics as unavailable, which is the degraded path, not the demo.
#
# Defaults to port 7860 so it runs unchanged on Hugging Face Spaces; $PORT
# overrides it for Render, Fly, Cloud Run and friends.

FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    MUJOCO_GL=egl \
    COACT_OV_DEVICE=AUTO \
    PORT=7860

RUN apt-get update && apt-get install -y --no-install-recommends \
        libegl1 \
        libgl1 \
        libglib2.0-0 \
        libgomp1 \
        libsm6 \
        libxext6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

# Hugging Face Spaces runs as a non-root user; matching it locally avoids
# permission surprises when the two are compared.
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 7860

# Fail loudly at build time if EGL rendering cannot initialise, rather than
# silently serving the no-physics fallback in production.
RUN python -c "\
import coact, mujoco; \
from coact.world import build_mjcf, default_items; \
m = mujoco.MjModel.from_xml_string(build_mjcf(default_items())); \
d = mujoco.MjData(m); mujoco.mj_forward(m, d); \
r = mujoco.Renderer(m, 240, 320); r.update_scene(d, camera='cam_A'); \
img = r.render(); assert img.mean() > 1, 'EGL rendered a blank frame'; \
print('EGL rendering OK', img.shape)"

CMD ["sh", "-c", "uvicorn coact.server:app --host 0.0.0.0 --port ${PORT:-7860}"]
