// deploy/00_deploy_streamer.js

const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("Streamer", {
    from: deployer,
    args: [],
    log: true,
  });

  const streamer = await ethers.getContract("Streamer", deployer);

  console.log("\n 🤹  Sending ownership to frontend address...\n");

  const ownerTx = await streamer.transferOwnership(
    "0x047821Dc2b13F680FeD9B006F0868bE43AcF4fe6"
  );

  console.log("\n       confirming...\n");
  const ownershipResult = await ownerTx.wait();
  if (ownershipResult) {
    console.log("       ✅ ownership transferred successfully!\n");
  }
};

module.exports.tags = ["Streamer"];
