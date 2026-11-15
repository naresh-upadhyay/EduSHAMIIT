"""
EduSHAMIIT Custom Visual Studio & Image Generation Engine.
Generates:
1. Razor-sharp Academic Formula Sheets & Scientific Diagrams (Matplotlib + LaTeX math typography).
2. Clean, Watermark-Free Photorealistic & Artistic AI Visuals (auto watermark-crop & enhancement).
All media is stored locally in assets/generated_images and served via /api/chat/media/{filename}.
"""
import os
import uuid
import re
import urllib.parse
import urllib.request
import logging
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)

# Ensure media directory exists
MEDIA_DIR = os.path.abspath(os.path.join(os.getcwd(), "assets", "generated_images"))
os.makedirs(MEDIA_DIR, exist_ok=True)


def is_academic_or_formula_request(prompt: str) -> bool:
    """Detect if the prompt is asking for formulas, equations, charts, or academic infographics."""
    p = prompt.lower()
    keywords = [
        "formula", "formulas", "equation", "equations", "math", "mathematics",
        "algebra", "trigonometry", "trigonometric", "calculus", "derivative", "integral",
        "geometry", "physics", "chemistry", "diagram", "chart", "cheat sheet",
        "unit circle", "periodic table", "kinematics", "newton", "matrix",
        "logarithm", "pythagoras", "quadratics", "identities", "limits", "graph"
    ]
    return any(k in p for k in keywords)


def generate_academic_infographic(prompt: str) -> Dict[str, Any]:
    """
    Generate an ultra-crisp, high-DPI academic formula sheet or diagram using Matplotlib & LaTeX MathText.
    Completely custom, razor-sharp, zero watermarks.
    """
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np

    p = prompt.lower()
    img_id = str(uuid.uuid4())[:8]
    filename = f"academic_sheet_{img_id}.png"
    filepath = os.path.join(MEDIA_DIR, filename)

    # Theme palette (EduSHAMIIT Slate & Electric Blue)
    bg_color = "#0B1120"
    card_bg = "#1E293B"
    text_light = "#F8FAFC"
    text_muted = "#94A3B8"

    # Determine topic specialization
    is_trig = any(k in p for k in ["trig", "sin", "cos", "tan", "angle", "identit"])
    is_calc = any(k in p for k in ["calculus", "derivative", "integral", "limit", "diff"])
    is_phys = any(k in p for k in ["physic", "newton", "gravity", "kinematic", "motion", "force", "energy"])
    is_algebra = any(k in p for k in ["algebra", "quadrat", "logarithm", "matrix", "polynomial"])

    fig = plt.figure(figsize=(12, 8), dpi=160, facecolor=bg_color)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.axis("off")
    ax.set_facecolor(bg_color)

    if is_trig and not ("multiple" in p or "all" in p):
        # ── Specialized Trigonometry Master Sheet ──
        ax.text(0.5, 0.95, "EduSHAMIIT • Trigonometry Master Reference", color="#38BDF8", fontsize=20, fontweight="bold", ha="center", va="top")
        ax.text(0.5, 0.90, "Essential Ratios, Pythagorean Identities & Double Angle Theorems", color=text_muted, fontsize=12, ha="center", va="top")

        # Card 1: Core Identities
        r1 = plt.Rectangle((0.05, 0.48), 0.42, 0.38, fill=True, color=card_bg, ec="#0284C7", lw=1.8, transform=ax.transAxes)
        ax.add_patch(r1)
        ax.text(0.08, 0.82, "PYTHAGOREAN IDENTITIES", color="#38BDF8", fontsize=11, fontweight="bold")
        ax.text(0.08, 0.75, r"$\sin^2(\theta) + \cos^2(\theta) = 1$", color=text_light, fontsize=13)
        ax.text(0.08, 0.68, r"$1 + \tan^2(\theta) = \sec^2(\theta)$", color=text_light, fontsize=13)
        ax.text(0.08, 0.61, r"$1 + \cot^2(\theta) = \csc^2(\theta)$", color=text_light, fontsize=13)
        ax.text(0.08, 0.54, r"$\tan(\theta) = \frac{\sin(\theta)}{\cos(\theta)} \quad \mid \quad \cot(\theta) = \frac{\cos(\theta)}{\sin(\theta)}$", color=text_light, fontsize=12)

        # Card 2: Compound & Double Angle
        r2 = plt.Rectangle((0.53, 0.48), 0.42, 0.38, fill=True, color=card_bg, ec="#7C3AED", lw=1.8, transform=ax.transAxes)
        ax.add_patch(r2)
        ax.text(0.56, 0.82, "DOUBLE & HALF ANGLE THEOREMS", color="#C084FC", fontsize=11, fontweight="bold")
        ax.text(0.56, 0.75, r"$\sin(2\theta) = 2\sin(\theta)\cos(\theta)$", color=text_light, fontsize=13)
        ax.text(0.56, 0.68, r"$\cos(2\theta) = \cos^2(\theta) - \sin^2(\theta) = 2\cos^2(\theta) - 1$", color=text_light, fontsize=12)
        ax.text(0.56, 0.61, r"$\tan(2\theta) = \frac{2\tan(\theta)}{1 - \tan^2(\theta)}$", color=text_light, fontsize=13)
        ax.text(0.56, 0.54, r"$\sin^2(\theta) = \frac{1 - \cos(2\theta)}{2} \quad \cos^2(\theta) = \frac{1 + \cos(2\theta)}{2}$", color=text_light, fontsize=12)

        # Card 3: Sum-to-Product & Product-to-Sum
        r3 = plt.Rectangle((0.05, 0.08), 0.90, 0.35, fill=True, color=card_bg, ec="#059669", lw=1.8, transform=ax.transAxes)
        ax.add_patch(r3)
        ax.text(0.08, 0.39, "SUM & DIFFERENCE FORMULAS", color="#34D399", fontsize=11, fontweight="bold")
        ax.text(0.08, 0.31, r"$\sin(A \pm B) = \sin(A)\cos(B) \pm \cos(A)\sin(B)$", color=text_light, fontsize=13)
        ax.text(0.08, 0.22, r"$\cos(A \pm B) = \cos(A)\cos(B) \mp \sin(A)\sin(B)$", color=text_light, fontsize=13)
        ax.text(0.08, 0.13, r"$\tan(A \pm B) = \frac{\tan(A) \pm \tan(B)}{1 \mp \tan(A)\tan(B)}$", color=text_light, fontsize=13)

        title = "Trigonometry Master Formula Sheet"

    elif is_calc and not ("multiple" in p or "all" in p):
        # ── Specialized Calculus Master Sheet ──
        ax.text(0.5, 0.95, "EduSHAMIIT • Calculus & Analysis Visual Guide", color="#A855F7", fontsize=20, fontweight="bold", ha="center", va="top")
        ax.text(0.5, 0.90, "Standard Derivatives, Integration Techniques & Series Rules", color=text_muted, fontsize=12, ha="center", va="top")

        # Card 1: Derivatives
        r1 = plt.Rectangle((0.05, 0.48), 0.42, 0.38, fill=True, color=card_bg, ec="#9333EA", lw=1.8, transform=ax.transAxes)
        ax.add_patch(r1)
        ax.text(0.08, 0.82, "DERIVATIVE RULES", color="#C084FC", fontsize=11, fontweight="bold")
        ax.text(0.08, 0.75, r"$\frac{d}{dx}[x^n] = n x^{n-1} \quad \mid \quad \frac{d}{dx}[e^{kx}] = k e^{kx}$", color=text_light, fontsize=12)
        ax.text(0.08, 0.68, r"Product:  $\frac{d}{dx}[uv] = u v' + v u'$", color=text_light, fontsize=13)
        ax.text(0.08, 0.61, r"Quotient:  $\frac{d}{dx}\left[\frac{u}{v}\right] = \frac{u'v - uv'}{v^2}$", color=text_light, fontsize=13)
        ax.text(0.08, 0.54, r"Chain Rule:  $\frac{d}{dx}[f(g(x))] = f'(g(x)) \cdot g'(x)$", color=text_light, fontsize=12)

        # Card 2: Standard Integrals
        r2 = plt.Rectangle((0.53, 0.48), 0.42, 0.38, fill=True, color=card_bg, ec="#0284C7", lw=1.8, transform=ax.transAxes)
        ax.add_patch(r2)
        ax.text(0.56, 0.82, "STANDARD INTEGRALS", color="#38BDF8", fontsize=11, fontweight="bold")
        ax.text(0.56, 0.75, r"$\int x^n \, dx = \frac{x^{n+1}}{n+1} + C \quad (n \neq -1)$", color=text_light, fontsize=13)
        ax.text(0.56, 0.68, r"$\int \frac{1}{x} \, dx = \ln|x| + C \quad \mid \quad \int e^x \, dx = e^x + C$", color=text_light, fontsize=12)
        ax.text(0.56, 0.61, r"$\int \sin(x) \, dx = -\cos(x) + C \quad \int \sec^2(x) \, dx = \tan(x) + C$", color=text_light, fontsize=12)
        ax.text(0.56, 0.54, r"Parts:  $\int u \, dv = uv - \int v \, du$", color=text_light, fontsize=13)

        # Card 3: Fundamental Theorem
        r3 = plt.Rectangle((0.05, 0.08), 0.90, 0.35, fill=True, color=card_bg, ec="#059669", lw=1.8, transform=ax.transAxes)
        ax.add_patch(r3)
        ax.text(0.08, 0.39, "FUNDAMENTAL THEOREMS & LIMITS", color="#34D399", fontsize=11, fontweight="bold")
        ax.text(0.08, 0.31, r"Fundamental Theorem of Calculus:  $\int_a^b f(x) \, dx = F(b) - F(a)$", color=text_light, fontsize=13)
        ax.text(0.08, 0.22, r"Special Limits:  $\lim_{x \to 0} \frac{\sin x}{x} = 1 \quad \mid \quad \lim_{x \to 0} \frac{e^x - 1}{x} = 1$", color=text_light, fontsize=13)
        ax.text(0.08, 0.13, r"Taylor Series:  $f(x) = \sum_{n=0}^{\infty} \frac{f^{(n)}(a)}{n!} (x - a)^n$", color=text_light, fontsize=13)

        title = "Calculus & Analysis Formula Guide"

    else:
        # ── Comprehensive Multi-Subject Master Sheet (Default for 'Multiple Formulas') ──
        ax.text(0.5, 0.95, "EduSHAMIIT • Comprehensive Master Formula Guide", color="#38BDF8", fontsize=20, fontweight="bold", ha="center", va="top")
        ax.text(0.5, 0.90, "Cross-Disciplinary Equations: Trigonometry, Calculus, Algebra & Physics", color=text_muted, fontsize=12, ha="center", va="top")

        # 1. Trigonometry Card (Top Left)
        r1 = plt.Rectangle((0.04, 0.47), 0.43, 0.38, fill=True, color=card_bg, ec="#0284C7", lw=1.8, transform=ax.transAxes)
        ax.add_patch(r1)
        ax.text(0.07, 0.81, "TRIGONOMETRIC IDENTITIES", color="#38BDF8", fontsize=11, fontweight="bold")
        ax.text(0.07, 0.74, r"$\sin^2(\theta) + \cos^2(\theta) = 1$", color=text_light, fontsize=13)
        ax.text(0.07, 0.67, r"$1 + \tan^2(\theta) = \sec^2(\theta)$", color=text_light, fontsize=13)
        ax.text(0.07, 0.60, r"$\sin(2\theta) = 2\sin(\theta)\cos(\theta)$", color=text_light, fontsize=13)
        ax.text(0.07, 0.53, r"$\cos(2\theta) = \cos^2(\theta) - \sin^2(\theta) = 2\cos^2(\theta) - 1$", color=text_light, fontsize=11.5)

        # 2. Calculus Card (Top Right)
        r2 = plt.Rectangle((0.53, 0.47), 0.43, 0.38, fill=True, color=card_bg, ec="#7C3AED", lw=1.8, transform=ax.transAxes)
        ax.add_patch(r2)
        ax.text(0.56, 0.81, "CALCULUS & ANALYSIS", color="#C084FC", fontsize=11, fontweight="bold")
        ax.text(0.56, 0.74, r"Product Rule:  $\frac{d}{dx}[uv] = u\frac{dv}{dx} + v\frac{du}{dx}$", color=text_light, fontsize=12)
        ax.text(0.56, 0.67, r"Power Rule:  $\int x^n \, dx = \frac{x^{n+1}}{n+1} + C \quad (n \neq -1)$", color=text_light, fontsize=12.5)
        ax.text(0.56, 0.60, r"Limit:  $\lim_{x \to 0} \frac{\sin(x)}{x} = 1 \quad \mid \quad \frac{d}{dx}[\ln x] = \frac{1}{x}$", color=text_light, fontsize=12)
        ax.text(0.56, 0.53, r"By Parts:  $\int u \, dv = uv - \int v \, du$", color=text_light, fontsize=12)

        # 3. Algebra & Geometry Card (Bottom Left)
        r3 = plt.Rectangle((0.04, 0.06), 0.43, 0.38, fill=True, color=card_bg, ec="#059669", lw=1.8, transform=ax.transAxes)
        ax.add_patch(r3)
        ax.text(0.07, 0.40, "ALGEBRA & GEOMETRY", color="#34D399", fontsize=11, fontweight="bold")
        ax.text(0.07, 0.33, r"Quadratic:  $x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$", color=text_light, fontsize=13)
        ax.text(0.07, 0.26, r"Pythagoras:  $a^2 + b^2 = c^2$", color=text_light, fontsize=13)
        ax.text(0.07, 0.19, r"Logarithm:  $\log_b(xy) = \log_b(x) + \log_b(y)$", color=text_light, fontsize=12)
        ax.text(0.07, 0.12, r"Binomial:  $(a + b)^n = \sum_{k=0}^n \binom{n}{k} a^{n-k} b^k$", color=text_light, fontsize=12)

        # 4. Physics Card (Bottom Right)
        r4 = plt.Rectangle((0.53, 0.06), 0.43, 0.38, fill=True, color=card_bg, ec="#D97706", lw=1.8, transform=ax.transAxes)
        ax.add_patch(r4)
        ax.text(0.56, 0.40, "PHYSICS & MECHANICS", color="#FBBF24", fontsize=11, fontweight="bold")
        ax.text(0.56, 0.33, r"Newton's 2nd Law:  $\mathbf{F} = m\mathbf{a} = \frac{d\mathbf{p}}{dt}$", color=text_light, fontsize=13)
        ax.text(0.56, 0.26, r"Kinematics:  $v^2 = u^2 + 2as \quad \mid \quad s = ut + \frac{1}{2}at^2$", color=text_light, fontsize=12)
        ax.text(0.56, 0.19, r"Mass-Energy:  $E = mc^2 \quad \mid \quad E = h\nu = \frac{hc}{\lambda}$", color=text_light, fontsize=12)
        ax.text(0.56, 0.12, r"Universal Gravity:  $F = G \frac{m_1 m_2}{r^2}$", color=text_light, fontsize=12)

        title = "Master Academic Formula Reference Sheet"

    # Watermark-free branding footer
    ax.text(0.5, 0.02, "EduSHAMIIT Custom Academic Visual Studio • Razor-Sharp LaTeX Output", color="#64748B", fontsize=10, ha="center", va="bottom")

    plt.savefig(filepath, format="png", facecolor=bg_color, bbox_inches="tight")
    plt.close(fig)

    media_url = f"/api/chat/media/{filename}"
    return {
        "success": True,
        "title": title,
        "filename": filename,
        "image_url": media_url,
        "markdown": f"![{title}]({media_url})",
        "result": f"Here is your high-precision academic visual reference:\n\n![{title}]({media_url})\n\n**{title}** — *Engineered with mathematical precision, crystal-clear typography, and zero watermarks.*"
    }


def generate_clean_photorealistic_image(prompt: str) -> Dict[str, Any]:
    """
    Generate clean, photorealistic visuals without watermarks.
    Fetches synthesis, crops off any bottom server-stamped logos/watermarks, enhances quality with PIL,
    and stores locally in assets/generated_images.
    """
    import io
    from PIL import Image, ImageEnhance

    img_id = str(uuid.uuid4())[:8]
    filename = f"visual_{img_id}.png"
    filepath = os.path.join(MEDIA_DIR, filename)

    encoded = urllib.parse.quote(prompt.strip())
    # Try fetching clean prompt
    urls_to_try = [
        f"https://image.pollinations.ai/prompt/{encoded}?width=800&height=800&nologo=true",
        f"https://image.pollinations.ai/prompt/{encoded}?nologo=true",
        f"https://image.pollinations.ai/prompt/{encoded}?model=flux&nologo=true",
    ]

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "image/*"
    }

    image_bytes = None
    for url in urls_to_try:
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=20) as resp:
                if resp.status == 200:
                    data = resp.read()
                    if len(data) > 1000:
                        image_bytes = data
                        break
        except Exception:
            continue

    if image_bytes:
        try:
            img = Image.open(io.BytesIO(image_bytes))
            w, h = img.size

            # ── Watermark Removal: Crop bottom 6% where diffusion hosts insert logos ──
            crop_h = int(h * 0.94)
            clean_img = img.crop((0, 0, w, crop_h))

            # ── Visual Polish: Slight sharpness and color boost ──
            sharpness = ImageEnhance.Sharpness(clean_img)
            clean_img = sharpness.enhance(1.15)
            color = ImageEnhance.Color(clean_img)
            clean_img = color.enhance(1.05)

            clean_img.save(filepath, format="PNG", quality=95)

            media_url = f"/api/chat/media/{filename}"
            clean_title = prompt.strip()[:60].title()
            return {
                "success": True,
                "title": clean_title,
                "filename": filename,
                "image_url": media_url,
                "markdown": f"![{clean_title}]({media_url})",
                "result": f"Here is your generated image:\n\n![{clean_title}]({media_url})\n\n*Prompt: {prompt.strip()} (Watermark-free, high-resolution)*"
            }
        except Exception as e:
            logger.error(f"Image processing error: {e}")

    # Fallback to academic/procedural studio if external download failed
    return generate_academic_infographic(prompt)


def generate_custom_image(prompt: str) -> Dict[str, Any]:
    """Smart router: routes academic/diagram prompts to MathText Studio, and photo prompts to clean visual engine."""
    if is_academic_or_formula_request(prompt):
        return generate_academic_infographic(prompt)
    else:
        return generate_clean_photorealistic_image(prompt)
