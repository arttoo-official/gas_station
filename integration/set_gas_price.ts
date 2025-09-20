import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { config } from "dotenv";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

config({ path: "./.env" });

async function setGasPrice() {
	const client = new SuiClient({
		url: process.env.SUI_RPC_URL || "https://fullnode.testnet.sui.io:443",
	});

	const packageId = process.env.PACKAGE_ID;
	const gasStationId = process.env.GAS_STATION_ID;
	const privateKeyBase64 = process.env.PRIVATE_KEY;
	const newGasPriceStr = '100000';

	if (!packageId || !gasStationId || !privateKeyBase64 || !newGasPriceStr) {
		throw new Error(
			"Missing required env vars: PACKAGE_ID, GAS_STATION_ID, PRIVATE_KEY, and NEW_GAS_PRICE (or pass as argv[2])"
		);
	}

	if (!/^\d+$/.test(newGasPriceStr)) {
		throw new Error("NEW_GAS_PRICE must be an unsigned integer string (micro-USDC)");
	}

	const keypair = Ed25519Keypair.fromSecretKey(privateKeyBase64);
	const signerAddress = keypair.getPublicKey().toSuiAddress();
	console.log("Signer (must be admin):", signerAddress);
	console.log("Setting gas price to (micro-USDC):", newGasPriceStr);

	// Optional: show current gas price
	try {
		const gs = await client.getObject({ id: gasStationId, options: { showContent: true } });
		const fields: any = (gs.data as any)?.content?.fields;
		if (fields?.gas_price != null) {
			console.log("Current gas price:", fields.gas_price.toString());
		}
	} catch {}

	const tx = new Transaction();
	tx.moveCall({
		target: `${packageId}::gas_station::set_gas_price`,
		arguments: [
			tx.object(gasStationId),
			tx.pure.u64(newGasPriceStr),
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

setGasPrice().catch((err) => {
	console.error(err);
	process.exit(1);
});


