#!/bin/bash

echo ""
echo "##################"
echo "# Create relayer #"
echo "##################"
echo ""

# Configure predefined mnemonic pharses
BINARY=rly
CHAIN_DIR=$(pwd)/data
CHAINID_1=test1
CHAINID_2=test2
RELAYER_DIR=/relayer
MNEMONIC_1="alley afraid soup fall idea toss can goose become valve initial strong forward bright dish figure check leopard decide warfare hub unusual join cart"
MNEMONIC_2="record gift you once hip style during joke field prize dust unique length more pencil transfer quit train device arrive energy sort steak upset"

# Kill any existing relayer process
pkill rly || true
sleep 2

# Remove existing config if it exists
if [ -f "$CHAIN_DIR/$RELAYER_DIR/config/config.yaml" ]; then
    echo "Removing existing relayer config..."
    rm -rf $CHAIN_DIR/$RELAYER_DIR/config
fi

# Ensure rly is installed
if ! [ -x "$(command -v $BINARY)" ]; then
    echo "$BINARY is required to run this script..."
    echo "You can download at https://github.com/cosmos/relayer"
    exit 1
fi

# Check if chains are running
if ! nc -z localhost 16657; then
    echo "ERROR: Chain 1 is not running on port 16657"
    exit 1
fi

if ! nc -z localhost 26657; then
    echo "ERROR: Chain 2 is not running on port 26657"
    exit 1
fi

echo "Initializing $BINARY..."
$BINARY config init --home $CHAIN_DIR/$RELAYER_DIR

echo "Adding configurations for both chains..."
$BINARY chains add-dir ./scripts/tests/relayer/chains --home $CHAIN_DIR/$RELAYER_DIR
$BINARY paths add $CHAINID_1 $CHAINID_2 test1-test2 --file ./scripts/tests/relayer/paths/test1-test2.json --home $CHAIN_DIR/$RELAYER_DIR

echo "Restoring accounts..."
$BINARY keys restore $CHAINID_1 testkey "$MNEMONIC_1" --home $CHAIN_DIR/$RELAYER_DIR
$BINARY keys restore $CHAINID_2 testkey "$MNEMONIC_2" --home $CHAIN_DIR/$RELAYER_DIR

echo "----------------------------------------"
echo "----> Creating clients and a connection..."
$BINARY tx connection test1-test2 --home $CHAIN_DIR/$RELAYER_DIR
sleep 3

echo "Creating a channel..."
$BINARY tx channel test1-test2 --home $CHAIN_DIR/$RELAYER_DIR
sleep 3

echo "Starting to listen relayer..."
$BINARY start test1-test2 --debug -p events -b 100 --home $CHAIN_DIR/$RELAYER_DIR > $CHAIN_DIR/relayer.log 2>&1 &
