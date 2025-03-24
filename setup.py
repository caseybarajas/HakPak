"""
HakPak - Flipper Zero Integration
Setup script for installation
"""

from setuptools import setup, find_packages
import os

# Read the contents of the README file
with open(os.path.join('flipper_integration', 'README.md'), encoding='utf-8') as f:
    long_description = f.read()

setup(
    name="hakpak-flipper",
    version="0.1.0",
    description="Flipper Zero integration for HakPak platform",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="Casey Barajas",
    author_email="casey@hakpak.io",
    url="https://github.com/caseybarajas/hakpak",
    packages=find_packages(),
    install_requires=[
        "pyserial>=3.5",
        "flask>=2.0.0",
        "flask-socketio>=5.0.0",
    ],
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Topic :: Software Development :: Libraries",
        "Topic :: Communications",
        "Topic :: System :: Hardware",
    ],
    python_requires=">=3.7",
    keywords="flipper zero, hakpak, pentesting, security, hardware",
) 