import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { config } from "dotenv";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

config({ path: "./.env" });

async function withdrawFunds() {
	const client = new SuiClient({
		url: process.env.SUI_RPC_URL || "https://fullnode.testnet.sui.io:443",
	});

	const packageId = process.env.PACKAGE_ID;
	const gasStationId = process.env.GAS_STATION_ID;
	const privateKeyBase64 = process.env.PRIVATE_KEY;

	if (!packageId || !gasStationId || !privateKeyBase64) {
		throw new Error(
			"Missing required env vars: PACKAGE_ID, GAS_STATION_ID, PRIVATE_KEY"
		);
	}

	const keypair = Ed25519Keypair.fromSecretKey(privateKeyBase64);
	const userAddress = keypair.getPublicKey().toSuiAddress();
	console.log("Signer (must be admin):", userAddress);

	const tx = new Transaction();
	tx.moveCall({
		target: `${packageId}::gas_station::withdraw_funds`,
		arguments: [tx.object(gasStationId)],
	});

	const result = await client.signAndExecuteTransaction({
		signer: keypair,
		transaction: tx,
		options: { showEffects: true, showObjectChanges: true },
	});

	console.log("Transaction executed successfully");
	console.log("Digest:", result.digest);
	if ((result as any).effects) console.log("Effects:", (result as any).effects);
	if (result.objectChanges) console.log("Object changes:", result.objectChanges);
}

withdrawFunds().catch((err) => {
	console.error(err);
	process.exit(1);
});


