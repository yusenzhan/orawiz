import hre from "hardhat";

describe("Feed", function () {
  describe("test",function (){
    it("should work",async function () {
      const feed = await hre.viem.getContractAt("NFTFloorPriceFeeds","0x528cb1ce480594f670f4aede6a1c9beda9850c86");
      const price = await feed.read.getLatestPrice();
      console.log(price);
    })
  })
});
