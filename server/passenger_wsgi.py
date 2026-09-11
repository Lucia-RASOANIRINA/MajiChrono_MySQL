"""Point d'entrée WSGI pour le gestionnaire d'applications DirectAdmin."""

import sys
from pathlib import Path

from a2wsgi import ASGIMiddleware

# Passenger peut charger le fichier depuis son répertoire de travail interne.
# Le dossier de l'application doit rester importable quelle que soit cette
# valeur, sinon le processus échoue avant même d'exposer /health.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.main import app

application = ASGIMiddleware(app)
