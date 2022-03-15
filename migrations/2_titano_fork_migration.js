const SECO = artifacts.require("SECO");

module.exports = async function (deployer, network, accounts) {
	await deployer.deploy(SECO, { from: accounts[0] });
};
