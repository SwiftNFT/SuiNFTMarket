import {
    Connection, Ed25519Keypair, JsonRpcProvider, RawSigner, TransactionBlock,
} from '@mysten/sui.js';

import * as dotenv from "dotenv";
import { execSync } from 'child_process';

async function main() {
    dotenv.config();

    const privkey = process.env.PRIVATE_KEY ?? "empty"
    const keypair = Ed25519Keypair.fromSecretKey(Buffer.from(privkey, 'hex'))

    const connection = new Connection({fullnode: "https://rpc.mainnet.sui.io:443"})
    const provider = new JsonRpcProvider(connection)
    const signer = new RawSigner(keypair, provider)

    const { modules, dependencies } = JSON.parse(
        execSync(
            `sui move build --dump-bytecode-as-base64 -p ../contract`,
            { encoding: "utf8" }
        )
    )

    console.log(modules)
    console.log(dependencies)

    const txb = new TransactionBlock();

    txb.setGasBudget(1000000000)

    const cap = txb.publish({
        modules: modules,
        dependencies: dependencies
    })
    console.log(cap)

    txb.transferObjects([cap], txb.pure(await signer.getAddress()));

    const tryResult = await signer.dryRunTransactionBlock({
        transactionBlock: txb
    });
    console.log({ tryResult }, tryResult.effects?.status)

    if (!tryResult.effects?.status){
        return
    }

    const result = await signer.signAndExecuteTransactionBlock({
        transactionBlock: txb, options: {showEffects: true}
    });
    console.log("status", result.effects?.status)

    console.log("gas used",result.effects.gasUsed)
    console.log("transactionDigest",result.effects.transactionDigest)
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});