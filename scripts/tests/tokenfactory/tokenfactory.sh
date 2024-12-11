#!/bin/bash

echo ""
echo "##########################################"
echo "# Create, Delete, Mint with Tokenfactory #"
echo "##########################################"
echo ""

BINARY=vectord
CHAIN_DIR=$(pwd)/data
TOKEN_DENOM=utoken$RANDOM
MINT_AMOUNT=1000000
CHAIN_ID_1=test1
CHAIN_ID_2=test2
GAS=2000000
FEES=1000000uvctr

# Get wallet addresses from the initialized test framework
WALLET_1=$($BINARY keys show val1 -a --keyring-backend test --home $CHAIN_DIR/$CHAIN_ID_1)
WALLET_2=$($BINARY keys show val2 -a --keyring-backend test --home $CHAIN_DIR/$CHAIN_ID_2)
WALLET_3=$($BINARY keys show wallet3 -a --keyring-backend test --home $CHAIN_DIR/$CHAIN_ID_1)

echo "Creating token denom $TOKEN_DENOM with $WALLET_1 on chain test1"
TX_HASH=$($BINARY tx tokenfactory create-denom $TOKEN_DENOM --from $WALLET_1 --home $CHAIN_DIR/$CHAIN_ID_1 --chain-id $CHAIN_ID_1 --node tcp://localhost:16657 --gas "$GAS" --fees "$FEES" --keyring-backend test -o json -y | jq -r '.txhash')
echo "TX_HASH: $TX_HASH"
sleep 3

echo "Querying tx $TX_HASH"
CREATED_RES_DENOM=$($BINARY query tx $TX_HASH -o json  --home $CHAIN_DIR/$CHAIN_ID_1 --node tcp://localhost:16657 | jq -r '.events[] | select(.type=="create_denom") | .attributes[] | select(.key=="new_token_denom") | .value')

if [ "$CREATED_RES_DENOM" != "factory/$WALLET_1/$TOKEN_DENOM" ]; then
    echo "ERROR: Tokenfactory creating denom error. Expected result 'factory/$WALLET_1/$TOKEN_DENOM', got '$CREATED_RES_DENOM'"
    exit 1
fi
echo "SUCCESS: Created denom $CREATED_RES_DENOM"
echo "----------------------------------------"

echo "Minting $MINT_AMOUNT units of $TOKEN_DENOM with $WALLET_1 on chain test1"
TX_HASH=$($BINARY tx tokenfactory mint $MINT_AMOUNT$CREATED_RES_DENOM --from $WALLET_1 --home $CHAIN_DIR/$CHAIN_ID_1 --chain-id $CHAIN_ID_1 --node tcp://localhost:16657 --gas "$GAS" --fees "$FEES" --keyring-backend test -o json -y | jq -r '.txhash')
echo "TX_HASH: $TX_HASH"
sleep 3

echo "SUCCESS: Minted $MINT_RES"
$BINARY query tx $TX_HASH -o json --home $CHAIN_DIR/$CHAIN_ID_1 --node tcp://localhost:16657 

echo "----------------------------------------"

echo "Querying $TOKEN_DENOM from $WALLET_1 on chain test1 to validate the amount minted"
BALANCE_RES_AMOUNT=$($BINARY query bank balances $WALLET_1 --denom $CREATED_RES_DENOM --node tcp://localhost:16657 -o json | jq -r '.amount')
if [ "$BALANCE_RES_AMOUNT" != $MINT_AMOUNT ]; then
    echo "ERROR: Tokenfactory minting error. Expected minted balance '$MINT_AMOUNT', got '$BALANCE_RES_AMOUNT'"
    exit 1
fi

echo "Burning 1 $TOKEN_DENOM from $WALLET_1 on chain test1"
TX_HASH=$($BINARY tx tokenfactory burn 1$CREATED_RES_DENOM --from $WALLET_1 --home $CHAIN_DIR/$CHAIN_ID_1 --chain-id $CHAIN_ID_1 --node tcp://localhost:16657 --gas "$GAS" --fees "$FEES" --keyring-backend test -o json -y | jq -r '.txhash')
sleep 3

BURN_RES=$($BINARY query tx $TX_HASH -o json --chain-id $CHAIN_ID_1 --home $CHAIN_DIR/$CHAIN_ID_1 --node tcp://localhost:16657 | jq -r '.logs[0].events[7].type')
if [ "$BURN_RES" != "tf_burn" ]; then
    echo "ERROR: Tokenfactory burning error. Expected result 'tf_burn', got '$BURN_RES'"
    exit 1
fi

echo "Querying $TOKEN_DENOM from $WALLET_1 on chain test1 to validate the burned amount"
BALANCES_AFTER_BURNING=$($BINARY query bank balances $WALLET_1 --denom $CREATED_RES_DENOM --chain-id $CHAIN_ID --node tcp://localhost:16657 -o json | jq -r '.amount')
if [ "$BALANCES_AFTER_BURNING" != 999999 ]; then
    echo "ERROR: Tokenfactory burning error. Expected balance '999999', got '$BALANCES_AFTER_BURNING'"
    exit 1
fi

echo "Sending 1 $TOKEN_DENOM from $WALLET_1 to $WALLET_3 on chain test1"
TX_HASH=$($BINARY tx bank send $WALLET_1 $WALLET_3 1$CREATED_RES_DENOM --from $WALLET_1 --home $CHAIN_DIR/$CHAIN_ID_1 --chain-id $CHAIN_ID_1 --node tcp://localhost:16657 --gas "$GAS" --fees "$FEES" --keyring-backend test -o json -y | jq -r '.txhash')
sleep 3

SEND_RES_MSG_TYPE=$($BINARY query tx $TX_HASH -o json --chain-id $CHAIN_ID_1 --home $CHAIN_DIR/$CHAIN_ID_1 --node tcp://localhost:16657 | jq -r '.logs[0].events[0].attributes[0].value')
if [ "$SEND_RES_MSG_TYPE" != "/cosmos.bank.v1beta1.MsgSend" ]; then
    echo "ERROR: Sending expected to be '/cosmos.bank.v1beta1.MsgSend' but got '$SEND_RES_MSG_TYPE'"
    exit 1
fi

echo "Querying $TOKEN_DENOM from $WALLET_3 on chain test1 to validate the funds were received"
BALANCES_RECEIVED=$($BINARY query bank balances $WALLET_3 --denom $CREATED_RES_DENOM --chain-id $CHAIN_ID --node tcp://localhost:16657 -o json | jq -r '.amount')
if [ "$BALANCES_RECEIVED" != 1 ]; then
    echo "ERROR: Token transfer error. Expected balance '1', got '$BALANCES_RECEIVED'"
    exit 1
fi

echo "IBC'ing 1 $TOKEN_DENOM from $WALLET_1 chain test1 to $WALLET_2 chain test2"
TX_HASH=$($BINARY tx ibc-transfer transfer transfer channel-0 $WALLET_2 1$CREATED_RES_DENOM --from $WALLET_1 --home $CHAIN_DIR/$CHAIN_ID_1 --chain-id $CHAIN_ID_1 --node tcp://localhost:16657 --gas "$GAS" --fees "$FEES" --keyring-backend test -o json -y | jq -r '.txhash')
sleep 3

IBC_SEND_RES=$($BINARY query tx $TX_HASH -o json --chain-id $CHAIN_ID_1 --home $CHAIN_DIR/$CHAIN_ID_1 --node tcp://localhost:16657 | jq -r '.logs[0].events[0].attributes[0].value')
if [ "$IBC_SEND_RES" != "/ibc.applications.transfer.v1.MsgTransfer" ]; then
    echo "ERROR: IBC'ing expected type '/ibc.applications.transfer.v1.MsgTransfer' but got '$IBC_SEND_RES'"
    exit 1
fi

echo "Waiting for IBC transfer to complete..."
IBC_RECEIVED_RES_AMOUNT=$($BINARY query bank balances $WALLET_2 --chain-id $CHAIN_ID_2 --node tcp://localhost:26657 -o json | jq -r '.balances[0].amount')
IBC_RECEIVED_RES_DENOM=""
while [ "$IBC_RECEIVED_RES_AMOUNT" != "1" ] || [ "${IBC_RECEIVED_RES_DENOM:0:4}" != "ibc/" ]; do
    sleep 2
    IBC_RECEIVED_RES_AMOUNT=$($BINARY query bank balances $WALLET_2 --chain-id $CHAIN_ID_2 --node tcp://localhost:26657 -o json | jq -r '.balances[0].amount')
    IBC_RECEIVED_RES_DENOM=$($BINARY query bank balances $WALLET_2 --chain-id $CHAIN_ID_2 --node tcp://localhost:26657 -o json | jq -r '.balances[0].denom')
    echo "Received: $IBC_RECEIVED_RES_AMOUNT $IBC_RECEIVED_RES_DENOM"
done

echo ""
echo "###################################################"
echo "# SUCCESS: Create, Delete, Mint with Tokenfactory  #"
echo "###################################################"
echo ""