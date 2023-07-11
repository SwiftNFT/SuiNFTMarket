import {
    Connection, Ed25519Keypair, JsonRpcProvider, RawSigner, TransactionBlock,UpgradePolicy
} from '@mysten/sui.js';

import * as dotenv from "dotenv";
import { execSync } from 'child_process';

async function main() {
    dotenv.config();

    const privkey = process.env.PRIVATE_KEY ?? "empty"
    const capId = process.env.UPGRADE_CAP ?? "empty"
    const packageId = process.env.PACKAGE_ID ?? "empty"
    const keypair = Ed25519Keypair.fromSecretKey(Buffer.from(privkey, 'hex'))

    const connection = new Connection({fullnode: "https://rpc.mainnet.sui.io:443"})
    const provider = new JsonRpcProvider(connection)
    const signer = new RawSigner(keypair, provider)

    const { modules, dependencies,digest } = JSON.parse(
        execSync(
            `sui move build --dump-bytecode-as-base64 -p ../contract`,
            { encoding: "utf8" }
        )
    )

    console.log(dependencies)

    const txb = new TransactionBlock();

    txb.setGasBudget(1_000_000_000)

    const ticket = txb.moveCall({
        target: '0x2::package::authorize_upgrade',
        arguments: [
            txb.object(capId),
            txb.pure(UpgradePolicy.COMPATIBLE),
            txb.pure(digest),
        ],
    });
    const receipt = txb.upgrade({
        modules,
        dependencies,
        packageId,
        ticket,
    })
    txb.moveCall({
        target: '0x2::package::commit_upgrade',
        arguments: [txb.object(capId), receipt],
    })
    console.log(receipt)

    txb.transferObjects([txb.object(capId)], txb.pure(await signer.getAddress()));

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


main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
