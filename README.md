## 🐍PowPy

**PowPy** - stands for Powershell Python Launcher

The tool allows to prepare portable solution for running Python projects on Windows
without installing Python to the system.
 - Download and preconfigure Python and pip
 - Download git portable to automate getting projects from Github
 - Create launcher scripts for starting project

### Installation Instructions
Run setup.ps1 file and follow the instructions
1. Select destination folder. Hit Enter to copy all data under C:\PowPy folder. It will include
    - Python embedded with installed pip
    - Git portable
    - Desired python project cloned repo
2. Enter exact python version. Hit Enter to download the most recent.
3. Clarify python architecture. Reply must be 64, 32 or arm64
4. Provide git repo http address, e.g. https://github.com/author/reponame.git

### To Do
 - add configuration for repo to _pth file
 - skip repo download
 - develop silent setup with default settings