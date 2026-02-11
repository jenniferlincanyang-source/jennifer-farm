const hre = require("hardhat");
require("dotenv").config();

async function main() {
  const JENNIFER = "0x4a0ad8f5083eb382bb4a4a334f1774955adce758";
  const LP_TOKEN = process.env.LP_TOKEN_ADDRESS;

  if (!LP_TOKEN || LP_TOKEN === "0x0000000000000000000000000000000000000000") {
    console.error("请先在 .env 中设置 LP_TOKEN_ADDRESS");
    console.log("步骤:");
    console.log("1. 去 PancakeSwap 添加 USDT/JENNIFER 流动性");
    console.log("2. 在 BscScan 查找 LP 合约地址");
    console.log("3. 填入 .env 的 LP_TOKEN_ADDRESS");
    process.exit(1);
  }

  console.log("部署 JenniferFarm...");
  console.log("  rewardToken (JENNIFER):", JENNIFER);
  console.log("  lpToken:", LP_TOKEN);

  const Farm = await hre.ethers.getContractFactory("JenniferFarm");
  const farm = await Farm.deploy(JENNIFER, LP_TOKEN);
  await farm.waitForDeployment();

  const addr = await farm.getAddress();
  console.log("\nJenniferFarm 部署成功!");
  console.log("合约地址:", addr);
  console.log("\n下一步:");
  console.log("1. 调用 JENNIFER.approve(farm, amount) 授权奖励代币");
  console.log("2. 调用 farm.fund(amount, duration) 注入奖励并启动挖矿");
  console.log("   示例: fund(1000000e18, 15552000) = 100万代币, 180天");
  console.log("3. 更新 frontend/index.html 中的 FARM_ADDRESS");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
