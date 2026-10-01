"""API v1 del cliente demo: contrato estable para apps externas (movil / web).

Reglas del contrato:
- Las apps consumen SOLO estos metodos, nunca /api/resource/<Doctype> directo.
- Dentro de v1 solo se agregan campos o endpoints; nunca se quitan ni se renombran.
- Un cambio incompatible va a api/v2, y v1 sigue viva mientras haya apps viejas en la calle.
- Cada endpoint tiene su test en tests/test_api_v1.py (si se rompe el contrato, el CI queda en rojo).
"""

API_VERSION = "1"
