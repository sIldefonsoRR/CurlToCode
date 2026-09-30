#!/bin/bash
# Runs the unit tests, then the integration tests: curl → code for every language,
# with every generated file syntax-checked by the installed toolchains (missing
# ones are skipped).
#
#   ./test.sh          unit + integration
#   ./test.sh --unit   unit tests only
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build

CORE_SOURCES=(Sources/Core/*.swift Sources/Core/Generators/*.swift)
# App sources minus the @main entry point, so the test runner can provide main
APP_SOURCES=($(ls Sources/App/*.swift | grep -v CurlToCodeApp.swift))

echo "==> Unit tests"
swiftc -Onone "${CORE_SOURCES[@]}" "${APP_SOURCES[@]}" Tests/Support/*.swift Tests/Unit/*.swift -o build/unit-tests
./build/unit-tests

[[ "${1:-}" == "--unit" ]] && exit 0

echo
echo "==> Integration tests"
OUT=build/test-output
rm -rf "$OUT" && mkdir -p "$OUT"
swiftc -O "${CORE_SOURCES[@]}" Tests/Integration/main.swift -o build/integration-tests
./build/integration-tests "$OUT"

echo
echo "Syntax-checking generated code..."
FAILED=0
report() { # language, ok count, bad count
    printf "  %-11s %s\n" "$1" "$2"
}
skip() { report "$1" "skipped ($2 not installed)"; }

check_each() { # language, extension, command...
    local lang=$1 ext=$2; shift 2
    local ok=0 bad=0
    for f in "$OUT/$lang"/*."$ext"; do
        if "$@" "$f" >/tmp/curltocode-check.log 2>&1; then
            ok=$((ok + 1))
        else
            bad=$((bad + 1)); FAILED=1
            echo "  ✗ $f"; sed 's/^/      /' /tmp/curltocode-check.log | head -20
        fi
    done
    report "$lang" "$ok valid, $bad invalid"
}

python_check() { python3 -c "import ast,sys; ast.parse(open(sys.argv[1], encoding='utf-8').read())" "$1"; }
check_each python py python_check

if command -v node >/dev/null; then check_each javascript mjs node --check; else skip javascript node; fi
if command -v ruby >/dev/null; then check_each ruby rb ruby -c; else skip ruby ruby; fi
check_each swift swift swiftc -typecheck
if command -v php >/dev/null; then check_each php php php -l; else skip php php; fi
if command -v gofmt >/dev/null; then check_each go go gofmt -e -l; else skip go go; fi
if javac -version >/dev/null 2>&1; then
    java_check() { d=$(mktemp -d); cp "$1" "$d/Main.java"; javac -d "$d" "$d/Main.java"; }
    check_each java java java_check
else
    skip java javac
fi

# Rust: every file becomes a binary in one cargo project, checked in one pass.
if command -v cargo >/dev/null; then
    R=build/rust-check
    mkdir -p "$R/src/bin" && rm -f "$R"/src/bin/*.rs
    cat > "$R/Cargo.toml" <<'EOF'
[package]
name = "curltocode-check"
version = "0.1.0"
edition = "2021"

[dependencies]
reqwest = { version = "0.12", features = ["blocking", "multipart"] }
EOF
    for f in "$OUT"/rust/*.rs; do cp "$f" "$R/src/bin/$(basename "$f")"; done
    n=$(ls "$R"/src/bin/*.rs | wc -l | tr -d ' ')
    if (cd "$R" && (cargo check --offline --bins -q 2>/tmp/curltocode-rust.log || cargo check --bins -q 2>/tmp/curltocode-rust.log)); then
        report rust "$n valid, 0 invalid"
    else
        FAILED=1; report rust "errors:"; grep -E "^(error|warning: unused)|-->" /tmp/curltocode-rust.log | head -40
    fi
else
    skip rust cargo
fi

# C#: build each file as the Program.cs of a scratch console project.
if command -v dotnet >/dev/null; then
    C=build/csharp-check
    if [ ! -f "$C/check.csproj" ]; then
        mkdir -p "$C"
        cat > "$C/check.csproj" <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>disable</ImplicitUsings>
    <Nullable>disable</Nullable>
  </PropertyGroup>
</Project>
EOF
    fi
    csharp_check() { cp "$1" "$C/Program.cs"; dotnet build "$C" -nologo -v q -clp:ErrorsOnly; }
    check_each csharp cs csharp_check
else
    skip csharp dotnet
fi

exit $FAILED
