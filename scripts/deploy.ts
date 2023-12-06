import hre from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  const network: any = process.env.HARDHAT_NETWORK;
  
  const [owner] = await hre.viem.getWalletClients();

  console.log("Deploying...");

  console.log("Deploying MainContract...");
  const maincontract = await hre.viem.deployContract("MainContract");

  console.log("Deployed!");

   // Save the addresses
   const addresses = {
    MainContract: maincontract.address,
  };

  console.log(addresses);

  // Save the addresses to a file
  const folderPath = "address";

  if (!fs.existsSync(folderPath)) fs.mkdirSync(folderPath);

  const filePath = path.join(folderPath, `address-${network}.json`);

  fs.writeFile(filePath, JSON.stringify(addresses, undefined, 4), (err) => {
    if (err) console.log("Write file error: " + err.message);
    else console.log(`Addresses are saved into ${filePath}...`);
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
