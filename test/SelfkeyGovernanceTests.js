const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Selfkey Governance Tests", function () {

    let contract;
    let authContract;

    let owner;
    let addr1;
    let addr2;
    let receiver;
    let signer;
    let addrs;

    const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

    beforeEach(async function () {
        [owner, addr1, addr2, receiver, signer, ...addrs] = await ethers.getSigners();

        const govContractFactory = await ethers.getContractFactory("SelfkeyGovernance");
        contract = await upgrades.deployProxy(govContractFactory, []);
        await contract.deployed();
    });

    describe("Deployment", function() {
        it("Deployed correctly", async function() {
        });
    });

    describe("Generic Governance functions", function() {
        it("Owner should be able to set a address setting", async function() {
            await expect(contract.connect(owner).setAddress(0, '0x4261EB067773a28913F8504648dBA48F7955D572', { from: owner.address }))
                .to.emit(contract, 'AddressUpdated')
                .withArgs(owner.address, 0, ZERO_ADDRESS, '0x4261EB067773a28913F8504648dBA48F7955D572');

            expect(await contract.addresses(0)).to.equal('0x4261EB067773a28913F8504648dBA48F7955D572');
        });

        it("Non-owner should not be able to set a address setting", async function() {
            await expect(contract.connect(addr1).setAddress(0, '0x4261EB067773a28913F8504648dBA48F7955D572', { from: addr1.address }))
                .to.be.revertedWith('Ownable: caller is not the owner');
        });
    })
});
