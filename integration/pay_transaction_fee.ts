import { Transaction } from "@mysten/sui/transactions";
import { SuiClient } from "@mysten/sui/client";
import { config } from "dotenv";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";

config({ path: "./.env" });

async function payTransactionFee() {
	const client = new SuiClient({
		url: process.env.SUI_RPC_URL || "https://fullnode.testnet.sui.io:443",
	});

	const packageId = process.env.PACKAGE_ID;
	const gasStationId = process.env.GAS_STATION_ID;
	const privateKeyBase64 = process.env.PRIVATE_KEY;
	const usdcCoinType =
		process.env.USDC_COIN_TYPE ||
		"0xa1ec7fc00a6f40db9693ad1415d0c193ad3906494428cf252621037bd7117e29::usdc::USDC"; // testnet USDC

	if (!packageId || !gasStationId || !privateKeyBase64) {
		throw new Error(
			"Missing required env vars: PACKAGE_ID, GAS_STATION_ID, PRIVATE_KEY"
		);
	}

	// Create keypair from private key
	const keypair = Ed25519Keypair.fromSecretKey(privateKeyBase64);
	const userAddress = keypair.getPublicKey().toSuiAddress();

	console.log("User address:", userAddress);

	// Fetch gas price from GasStation object
	console.log("Fetching GasStation state...");
	const gsObject = await client.getObject({
		id: gasStationId,
		options: { showContent: true },
	});

	const fields: any = (gsObject.data as any)?.content?.dataType
		? (gsObject.data as any).content.fields
		: (gsObject.data as any)?.content?.fields;
	if (!fields) {
		throw new Error("Failed to read GasStation fields; is the object id correct?");
	}
	const gasPriceStr: string = fields.gas_price?.toString();
	if (!gasPriceStr) {
		throw new Error("gas_price not found on GasStation object");
	}
	console.log("Required gas price (micro-USDC):", gasPriceStr);

	// Get all USDC coins owned by the user
	console.log("Fetching USDC coins...");
	const coins = await client.getCoins({ owner: userAddress, coinType: usdcCoinType });
	if (!coins.data.length) throw new Error("No USDC coins found for the wallet");

	const total = coins.data.reduce((acc, c) => acc + BigInt(c.balance), 0n);
	if (total < BigInt(gasPriceStr)) {
		throw new Error(
			`Insufficient USDC. Have: ${total.toString()}, Need: ${gasPriceStr}`
		);
	}
	console.log(`USDC balance: ${total.toString()}`);

	const tx = new Transaction();

	// Merge if multiple coins
	let primary = tx.object(coins.data[0].coinObjectId);
	if (coins.data.length > 1) {
		const toMerge = coins.data.slice(1).map((c) => tx.object(c.coinObjectId));
		tx.mergeCoins(primary, toMerge);
	}

	// Split exact gas price
	const [paymentCoin] = tx.splitCoins(primary, [tx.pure.u64(gasPriceStr)]);

	// Call pay_transaction_fee
	tx.moveCall({
		target: `${packageId}::gas_station::pay_transaction_fee`,
		arguments: [tx.object(gasStationId), paymentCoin, tx.object(SUI_CLOCK_OBJECT_ID)],
		// No typeArguments: function expects Coin<USDC>, not generic
	});

	// Sign and execute
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

payTransactionFee().catch((err) => {
	console.error(err);
	process.exit(1);
});


