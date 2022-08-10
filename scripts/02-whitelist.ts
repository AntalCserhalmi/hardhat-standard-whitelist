import Web3 from "web3";
import { AbiItem } from "web3-utils";
import { TransactionConfig, SignedTransaction } from "web3-core";
import { MerkleTree } from "merkletreejs";
import keccak256 from "keccak256";
import fs from "fs";
import contract from "../artifacts/contracts/StandardERC721Whitelist.sol/StandardERC721Whitelist.json";

type Wallets = {
    wallets: string[]
};

require("dotenv").config();

const API_URL = process.env.API_URL;
const PUBLIC_KEY = process.env.PUBLIC_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

if (API_URL === undefined) {
    console.log("API URL IS UNDEFINED");
    process.exit(1);
}

if (PUBLIC_KEY === undefined) {
    console.log("PUBLIC KEY IS DEFINED");
    process.exit(1);
}

if (PRIVATE_KEY === undefined) {
    console.log("PRIVATE KEY IS DEFINED");
    process.exit(1);
}

const web3 = new Web3(API_URL);
const contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const nftContract = new web3.eth.Contract(contract.abi as AbiItem[], contractAddress);

const readWallets = () => {
    const file = fs.readFileSync("wallets.json", "utf-8");
    const obj: Wallets = JSON.parse(file);

    return obj.wallets;
};

const openWhitelist = async () => {
    const wallets = readWallets();
    console.log(wallets);
    const leafNodes = wallets.map(address => keccak256(address));
    const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });
    const rootHash = `0x${merkleTree.getRoot().toString("hex")}`;

    const contractRoot = await nftContract.methods.merkleRoot().call();

    console.log(contractRoot);

    if (contractRoot !== rootHash) {
        console.log(`Updating roothash to ${rootHash}...`);
        const nonce = await web3.eth.getTransactionCount(PUBLIC_KEY, "latest");
        const tx: TransactionConfig = {
            from: PUBLIC_KEY,
            to: contractAddress,
            nonce: nonce,
            gasPrice: "10000000000",
            gas: 70000,
            data: nftContract.methods.setMerkleRoot(rootHash).encodeABI()
        }

        const signPromise: Promise<SignedTransaction> = web3.eth.accounts.signTransaction(tx, PRIVATE_KEY);

        signPromise.then((signedTx: SignedTransaction) => {
            if (signedTx.rawTransaction === undefined)
                return;

            web3.eth.sendSignedTransaction(signedTx.rawTransaction, async (err: Error, hash: string) => {
                if (!err) {
                    console.log(`The hash of your transaction is: ${hash}`);
                } else {
                    console.log(`Something went wrong: ${err}`);
                }
            });

        });
    }
};



openWhitelist().catch(err => console.log(err));