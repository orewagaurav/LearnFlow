#!/bin/bash

# ============================================================
#  LearnFlow — One-Click Project Launcher
#  Starts: MySQL → Spring Boot Backend → Vite Frontend
#  Stop:   Press Ctrl+C (gracefully shuts everything down)
# ============================================================

set -e

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Paths ────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$PROJECT_DIR/Backend"
FRONTEND_DIR="$PROJECT_DIR/Frontend"
BREW="/opt/homebrew/bin/brew"
MYSQL="/opt/homebrew/opt/mysql/bin/mysql"
NPM="/opt/homebrew/bin/npm"
NODE="/opt/homebrew/bin/node"

# ── PID tracking ─────────────────────────────────────────────
BACKEND_PID=""
FRONTEND_PID=""

# ── Helpers ──────────────────────────────────────────────────
log()    { echo -e "${CYAN}[LearnFlow]${NC} $1"; }
ok()     { echo -e "${GREEN}  ✔ $1${NC}"; }
warn()   { echo -e "${YELLOW}  ⚠ $1${NC}"; }
fail()   { echo -e "${RED}  ✖ $1${NC}"; }
header() { echo -e "\n${BOLD}${BLUE}━━━ $1 ━━━${NC}\n"; }

# ── Cleanup on exit ─────────────────────────────────────────
cleanup() {
    echo ""
    header "Shutting Down"

    if [ -n "$FRONTEND_PID" ] && kill -0 "$FRONTEND_PID" 2>/dev/null; then
        log "Stopping Frontend (PID $FRONTEND_PID)..."
        kill "$FRONTEND_PID" 2>/dev/null
        wait "$FRONTEND_PID" 2>/dev/null
        ok "Frontend stopped"
    fi

    if [ -n "$BACKEND_PID" ] && kill -0 "$BACKEND_PID" 2>/dev/null; then
        log "Stopping Backend (PID $BACKEND_PID)..."
        kill "$BACKEND_PID" 2>/dev/null
        wait "$BACKEND_PID" 2>/dev/null
        ok "Backend stopped"
    fi

    log "MySQL left running (use '$BREW services stop mysql' to stop)"
    echo -e "\n${GREEN}${BOLD}  LearnFlow stopped. Goodbye! 👋${NC}\n"
    exit 0
}
trap cleanup SIGINT SIGTERM

# ── Banner ───────────────────────────────────────────────────
clear
echo -e "${BOLD}${BLUE}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║         🚀  LearnFlow  Launcher           ║"
echo "  ║       Learning Management System          ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${NC}"

# ── 1. Verify Prerequisites ─────────────────────────────────
header "Checking Prerequisites"

# Java
if command -v java &>/dev/null; then
    JAVA_VER=$(java -version 2>&1 | head -1 | awk -F'"' '{print $2}')
    ok "Java: $JAVA_VER"
else
    fail "Java not found. Please install JDK 17+."
    exit 1
fi

# Node
if [ -x "$NODE" ]; then
    NODE_VER=$("$NODE" --version 2>&1)
    ok "Node.js: $NODE_VER"
elif command -v node &>/dev/null; then
    NODE=$(command -v node)
    NPM=$(command -v npm)
    NODE_VER=$(node --version 2>&1)
    ok "Node.js: $NODE_VER"
else
    fail "Node.js not found. Please install Node.js."
    exit 1
fi

# Brew
if [ -x "$BREW" ]; then
    ok "Homebrew: found"
elif command -v brew &>/dev/null; then
    BREW=$(command -v brew)
    ok "Homebrew: found"
else
    fail "Homebrew not found. Please install Homebrew."
    exit 1
fi

# MySQL binary
if [ -x "$MYSQL" ]; then
    ok "MySQL client: found"
elif command -v mysql &>/dev/null; then
    MYSQL=$(command -v mysql)
    ok "MySQL client: found"
else
    fail "MySQL not found. Run: brew install mysql"
    exit 1
fi

# ── 2. Start MySQL ──────────────────────────────────────────
header "Starting MySQL"

if "$BREW" services list 2>/dev/null | grep mysql | grep -q started; then
    ok "MySQL already running"
else
    log "Starting MySQL service..."
    "$BREW" services start mysql >/dev/null 2>&1
    sleep 3
    ok "MySQL started"
fi

# Verify connection & create database
log "Verifying database connection..."
if "$MYSQL" -u root -proot123 -e "CREATE DATABASE IF NOT EXISTS learnFlowDB;" 2>/dev/null; then
    ok "Database 'learnFlowDB' ready"
else
    fail "Cannot connect to MySQL. Check your root password."
    fail "Try: mysql -u root -p   (and enter your password)"
    exit 1
fi

# ── 3. Start Backend ────────────────────────────────────────
header "Starting Spring Boot Backend"

cd "$BACKEND_DIR"

# Fix Maven wrapper permissions if needed
if [ -f mvnw ]; then
    chmod +x mvnw 2>/dev/null
    xattr -cr mvnw 2>/dev/null || true
fi

log "Building and starting backend (port 8080)..."
./mvnw spring-boot:run -q 2>&1 &
BACKEND_PID=$!

# Wait for backend to be ready
log "Waiting for backend to start..."
RETRIES=0
MAX_RETRIES=30
while [ $RETRIES -lt $MAX_RETRIES ]; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/courses 2>/dev/null | grep -qE "200|204|401"; then
        ok "Backend running at ${BOLD}http://localhost:8080${NC}"
        break
    fi
    RETRIES=$((RETRIES + 1))
    sleep 2
done

if [ $RETRIES -eq $MAX_RETRIES ]; then
    fail "Backend failed to start within 60 seconds. Check logs above."
    cleanup
    exit 1
fi

# ── 4. Start Frontend ───────────────────────────────────────
header "Starting React Frontend"

cd "$FRONTEND_DIR"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    log "Installing dependencies (first run)..."
    "$NPM" install --silent 2>&1
    ok "Dependencies installed"
fi

log "Starting Vite dev server (port 5173)..."
export PATH="/opt/homebrew/bin:$PATH"
"$NPM" run dev 2>&1 &
FRONTEND_PID=$!
sleep 3

if kill -0 "$FRONTEND_PID" 2>/dev/null; then
    ok "Frontend running at ${BOLD}http://localhost:5173${NC}"
else
    fail "Frontend failed to start. Check logs above."
    cleanup
    exit 1
fi

# ── 5. Ready! ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║       ✅  LearnFlow is LIVE!              ║"
echo "  ╠═══════════════════════════════════════════╣"
echo "  ║                                           ║"
echo "  ║  Frontend:  http://localhost:5173          ║"
echo "  ║  Backend:   http://localhost:8080          ║"
echo "  ║  Database:  learnFlowDB @ localhost:3306   ║"
echo "  ║                                           ║"
echo "  ║  Press Ctrl+C to stop all services        ║"
echo "  ║                                           ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${NC}"

# Keep script alive — wait for background processes
wait
