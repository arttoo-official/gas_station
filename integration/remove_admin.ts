import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { config } from "dotenv";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

config({ path: "./.env" });

async function removeAdmin() {
	const client = new SuiClient({
		url: process.env.SUI_RPC_URL || "https://fullnode.testnet.sui.io:443",
	});

	const packageId = process.env.PACKAGE_ID;
	const gasStationId = process.env.GAS_STATION_ID;
	const privateKeyBase64 = process.env.PRIVATE_KEY;
	const adminToRemove = '0xbbb95be5282519238e7576099a40a794702303ad114e1ee2a5f25e9001d901a5';

	if (!packageId || !gasStationId || !privateKeyBase64 || !adminToRemove) {
		throw new Error(
			"Missing required env vars: PACKAGE_ID, GAS_STATION_ID, PRIVATE_KEY, ADMIN_TO_REMOVE_ADDRESS"
		);
	}

	const keypair = Ed25519Keypair.fromSecretKey(privateKeyBase64);
	const userAddress = keypair.getPublicKey().toSuiAddress();
	console.log("Signer (must be admin):", userAddress);
	console.log("Removing admin:", adminToRemove);

	const tx = new Transaction();
	tx.moveCall({
		target: `${packageId}::gas_station::remove_admin`,
		arguments: [
			tx.object(gasStationId),
			tx.pure.address(adminToRemove),
		],
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

removeAdmin().catch((err) => {
	console.error(err);
	process.exit(1);
});


