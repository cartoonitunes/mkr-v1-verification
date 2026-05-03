#!/bin/bash
# Byte-for-byte verification of MKR v1 (the original Maker Governance Token).
# On-chain: 0xc66ea802717bfb9833400264dd12c2bceaa34a6d, deployed Mar 28 2016 (block 1,233,109)
set -e

ADDRESS="0xc66ea802717bfb9833400264dd12c2bceaa34a6d"
SOLJSON_VERSION="v0.3.2+commit.81ae2a78"
SOLJSON_URL="https://binaries.soliditylang.org/bin/soljson-${SOLJSON_VERSION}.js"
SOLJSON_LOCAL="/tmp/soljson-${SOLJSON_VERSION}.js"
WORK="/tmp/mkr-v1-verify-$$"
mkdir -p "$WORK"
trap "rm -rf $WORK" EXIT

echo "==> Fetching soljson ${SOLJSON_VERSION}..."
if [ ! -f "$SOLJSON_LOCAL" ]; then
  curl -sSfL "$SOLJSON_URL" -o "$SOLJSON_LOCAL"
fi

echo "==> Installing solc wrapper..."
cd "$WORK"
npm init -y >/dev/null 2>&1
npm install --silent solc@0.4.26 >/dev/null 2>&1

cd "$OLDPWD"

echo "==> Compiling DSTokenFrontend.sol..."
node -e "
const fs = require('fs');
const solcWrapper = require('${WORK}/node_modules/solc');
const source = fs.readFileSync('DSTokenFrontend.sol', 'utf8');
const soljson = require('${SOLJSON_LOCAL}');
const compiler = solcWrapper.setupMethods(soljson);
let result = compiler.compile(source, 0); // optimizer OFF
if (typeof result === 'string') result = JSON.parse(result);
const c = result.contracts['DSTokenFrontend'] || result.contracts[':DSTokenFrontend'];
fs.writeFileSync('${WORK}/compiled_runtime.hex', c.runtimeBytecode);
"

echo "==> Comparing to on-chain runtime..."
COMPILED_SHA=$(shasum -a 256 "${WORK}/compiled_runtime.hex" | awk '{print $1}')
ONCHAIN_SHA=$(shasum -a 256 onchain_runtime.hex | awk '{print $1}')
echo "  Compiled: $COMPILED_SHA"
echo "  On-chain: $ONCHAIN_SHA"

if diff -q "${WORK}/compiled_runtime.hex" onchain_runtime.hex > /dev/null 2>&1; then
  echo "✅ EXACT BYTECODE MATCH (3040 bytes)"
  exit 0
else
  echo "❌ MISMATCH"
  diff "${WORK}/compiled_runtime.hex" onchain_runtime.hex | head -20
  exit 1
fi
