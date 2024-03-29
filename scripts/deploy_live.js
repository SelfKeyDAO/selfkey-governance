const { ethers, upgrades } = require('hardhat');

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const contractFactory = await hre.ethers.getContractFactory("SelfkeyGovernance");
    const contract = await upgrades.deployProxy(contractFactory, [], { timeout: 300000 });
    await contract.deployed();

    console.log("Deployed contract address:", contract.address);

    // INFO: verify contract after deployment
    // npx hardhat verify --network mumbai 0x8860868aE39c8690B49451E9bcE3EB884FF79B68
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
