import Web3 from "web3";
import { AbiItem } from "web3-utils";
import { TransactionConfig, SignedTransaction } from "web3-core"; 
import contract from "../artifacts/contracts/StandardERC721Whitelist.sol/StandardERC721Whitelist.json";


require("dotenv").config();

const API_URL = process.env.API_URL;
const PUBLIC_KEY = process.env.PUBLIC_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

if (API_URL === undefined){
    console.log("API URL IS UNDEFINED");
    process.exit(1);
}

if (PUBLIC_KEY === undefined){
    console.log("PUBLIC KEY IS DEFINED");
    process.exit(1);
}

if (PRIVATE_KEY === undefined){
    console.log("PRIVATE KEY IS DEFINED");
    process.exit(1);
}

const web3 = new Web3(API_URL);
const contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const nftContract = new web3.eth.Contract(contract.abi as AbiItem[], contractAddress);

const mintStatus = async () => {

    const mintStatus = await nftContract.methods.mintEnabled().call();
    if (!mintStatus) {
        console.log("Enable minting...");
        const nonce = await web3.eth.getTransactionCount(PUBLIC_KEY, "latest");

        const tx: TransactionConfig = {
            from: PUBLIC_KEY,
            to: contractAddress,
            nonce: nonce,
            gasPrice: "10000000000",
            gas: 50000,
            data: nftContract.methods.setMintStatus(true).encodeABI()
        }

        const signPromise: Promise<SignedTransaction> = web3.eth.accounts.signTransaction(tx, PRIVATE_KEY);

        signPromise.then(async (signedTx: SignedTransaction) => {
            if (signedTx.rawTransaction === undefined)
                return;

            await web3.eth.sendSignedTransaction(signedTx.rawTransaction, (err: Error, hash: string) => {
                if (!err) {
                    console.log(`The hash of your transaction is: ${hash}`);
                } else {
                    console.log(`Something went wrong: ${err}`);
                }
            })
        });
    }
};

mintStatus().catch(err => console.log(err));
