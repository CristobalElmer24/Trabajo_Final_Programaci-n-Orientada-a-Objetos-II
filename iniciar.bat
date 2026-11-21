@echo off
chcp 65001 >nul
echo Iniciando MediGest... (se abrira el navegador en http://localhost:8080)
mvn -q compile exec:java
pause
