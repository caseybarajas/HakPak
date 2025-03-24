from flask import Flask
from flask_socketio import SocketIO
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize Flask-SocketIO
socketio = SocketIO()

def create_app(test_config=None):
    # Create and configure the app
    app = Flask(__name__, instance_relative_config=True)
    app.config.from_mapping(
        SECRET_KEY=os.environ.get('SECRET_KEY', 'dev'),
        DATABASE=os.path.join(app.instance_path, 'hakpak.sqlite'),
    )

    if test_config is None:
        # Load the instance config, if it exists, when not testing
        app.config.from_pyfile('config.py', silent=True)
    else:
        # Load the test config if passed in
        app.config.from_mapping(test_config)

    # Ensure the instance folder exists
    try:
        os.makedirs(app.instance_path)
    except OSError:
        pass

    # Register blueprints
    from app.controllers.dashboard import bp as dashboard_bp
    app.register_blueprint(dashboard_bp)
    
    from app.controllers.kali_tools import bp as kali_tools_bp
    app.register_blueprint(kali_tools_bp)
    
    from app.controllers.flipper import bp as flipper_bp
    app.register_blueprint(flipper_bp)
    
    from app.controllers.scan_tools import bp as scan_tools_bp
    app.register_blueprint(scan_tools_bp)
    
    from app.controllers.settings import bp as settings_bp
    app.register_blueprint(settings_bp)

    # Initialize SocketIO with app
    socketio.init_app(app)
    
    return app 