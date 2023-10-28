// scripts/propose_upgrade.js
const { defender } = require('hardhat');

async function main() {
  const proxyAddress = '0xda9783A24fa2D9aC452246b96029A9d1d40ECFE1';

  const contract = await ethers.getContractFactory("SelfkeyPoiLock");
  console.log("Preparing proposal...");
  const proposal = await defender.proposeUpgrade(proxyAddress, contract);
  console.log("Upgrade proposal created at:", proposal.url);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  })
