## 🐍PowPy

**PowPy** is a portable Python Launcher for Windows

The tool allows to prepare portable solution for running Python projects on Windows
without installing Python to the system.
 - Download and preconfigure Python and pip
 - Download git portable to automate getting projects from Github
 - Create launcher scripts for starting project

### Installation Instructions
```powershell
.\setup.ps1
```
Running **setup.ps1** without parameters will download everything to C:\PowPy
and shows prompt
```powershell
Selected path: C:\PowPy
Enter Git Repository URL (http):
```
Paste http path to clone desired repo. It has format like https://github.com/author/repo_name.git
It is possible to skip repo download. In this case python _pth file must be updated manually.

It is posible to run the script with parameters
```powershell
.\setup.ps1 -RootPath C:\MyProject -RepoUrl https://github.com/author/repo_name.git
```

### Project Folder
setup.ps1 creates the following folder structure:\
\
📁 PowPy\
 ├── 📁 Git\
 ├── 📁 Python\
 │    └──📄python3xx._pth\
 └── 📁 Your Repo\
\
📄python3xx._pth:
```
python314.zip
.
Lib\site-packages
..\Your Repo\

# Uncomment to run site.main() automatically
import site
```