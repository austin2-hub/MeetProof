
import { describe, expect, it, beforeEach } from "vitest";
import { tupleCV, uintCV, intCV, bufferCV, boolCV } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const address3 = accounts.get("wallet_3")!;
const deployer = accounts.get("deployer")!;

describe("MeetProof Security Tests", () => {
  beforeEach(() => {
    // Reset simnet state before each test
    simnet.mineEmptyBlock();
  });

  describe("Basic Functionality", () => {
    it("should create a session successfully with valid inputs", () => {
      const validSecret = bufferCV(new Uint8Array(32).fill(97)); // 32 bytes of 'a'
      const location = tupleCV({
        lat: intCV(40000000),
        lon: intCV(-74000000)
      }); // NYC coordinates
      
      const { result } = simnet.callPublicFn(
        "meetproofcontract",
        "create-session",
        [
          validSecret,
          location,
          uintCV(100), // radius
          uintCV(10),  // duration
          uintCV(2),   // min-participants
          uintCV(5)    // max-participants
        ],
        address1
      );
      
      // The result should be (ok u1)
      expect(result).toBeDefined();
      expect(result.type).toBe("ok");
      expect(result.value).toBeUint(1); // First session should have ID 1
    });

    it("should verify participation successfully", () => {
      const validSecret = bufferCV(new Uint8Array(32).fill(97)); // 32 bytes of 'a'
      const location = tupleCV({
        lat: intCV(40000000),
        lon: intCV(-74000000)
      });
      
      // Create a session
      const { result: createResult } = simnet.callPublicFn(
        "meetproofcontract",
        "create-session",
        [
          validSecret,
          location,
          uintCV(100),
          uintCV(10),
          uintCV(2),
          uintCV(5)
        ],
        address1
      );
      
      expect(createResult).toBeDefined();
      expect(createResult.type).toBe("ok");
      const sessionId = createResult.value;
      
      // Verify participation
      const { result } = simnet.callPublicFn(
        "meetproofcontract",
        "verify-participation",
        [
          sessionId,
          validSecret,
          location
        ],
        address2
      );
      
      expect(result).toBeDefined();
      expect(result.type).toBe("ok");
    });
  });

  describe("Input Validation Security", () => {
    it("should reject secrets that are too short", () => {
      const shortSecret = bufferCV(new Uint8Array([97, 98, 99])); // "abc" - 3 bytes, less than MIN-SECRET-LENGTH (4)
      const location = tupleCV({
        lat: intCV(40000000),
        lon: intCV(-74000000)
      }); // NYC coordinates
      
      const { result } = simnet.callPublicFn(
        "meetproofcontract",
        "create-session",
        [
          shortSecret,
          location,
          uintCV(100), // radius
          uintCV(10),  // duration
          uintCV(2),   // min-participants
          uintCV(5)    // max-participants
        ],
        address1
      );
      
      expect(result).toBeDefined();
      expect(result.type).toBe("err");
      expect(result.value).toBeUint(101); // ERR-INVALID-SECRET
    });

    it("should reject secrets that are too long", () => {
      const longSecret = bufferCV(new Uint8Array(50).fill(97)); // 50 bytes, more than MAX-SECRET-LENGTH (32)
      const location = tupleCV({
        lat: intCV(40000000),
        lon: intCV(-74000000)
      });
      
      const { result } = simnet.callPublicFn(
        "meetproofcontract",
        "create-session",
        [
          longSecret,
          location,
          uintCV(100),
          uintCV(10),
          uintCV(2),
          uintCV(5)
        ],
        address1
      );
      
      expect(result).toBeDefined();
      expect(result.type).toBe("err");
      expect(result.value).toBeUint(101); // ERR-INVALID-SECRET
    });

    it("should reject invalid location coordinates", () => {
      const validSecret = bufferCV(new Uint8Array(32).fill(97)); // 32 bytes
      const invalidLocation = tupleCV({
        lat: intCV(95000000), // Invalid lat > 90
        lon: intCV(-74000000)
      });
      
      const { result } = simnet.callPublicFn(
        "meetproofcontract",
        "create-session",
        [
          validSecret,
          invalidLocation,
          uintCV(100),
          uintCV(10),
          uintCV(2),
          uintCV(5)
        ],
        address1
      );
      
      expect(result).toBeDefined();
      expect(result.type).toBe("err");
      expect(result.value).toBeUint(100); // ERR-INVALID-LOCATION
    });

    it("should reject invalid radius values", () => {
      const validSecret = bufferCV(new Uint8Array(32).fill(97));
      const location = tupleCV({
        lat: intCV(40000000),
        lon: intCV(-74000000)
      });
      
      const { result } = simnet.callPublicFn(
        "meetproofcontract",
        "create-session",
        [
          validSecret,
          location,
          uintCV(5), // radius too small (< MIN-RADIUS 10)
          uintCV(10),
          uintCV(2),
          uintCV(5)
        ],
        address1
      );
      
      expect(result).toBeDefined();
      expect(result.type).toBe("err");
      expect(result.value).toBeUint(108); // ERR-INVALID-RADIUS
    });
  });

  describe("Access Control Security", () => {
    it("should only allow contract owner to pause contract", () => {
      const { result } = simnet.callPublicFn(
        "meetproofcontract",
        "set-contract-paused",
        [boolCV(true)],
        address1 // Not the contract owner
      );
      
      expect(result).toBeDefined();
      expect(result.type).toBe("err");
      expect(result.value).toBeUint(401); // ERR-NOT-AUTHORIZED
    });

    it("should allow contract owner to pause contract", () => {
      const { result } = simnet.callPublicFn(
        "meetproofcontract",
        "set-contract-paused",
        [boolCV(true)],
        deployer // Contract owner
      );
      
      expect(result).toBeDefined();
      expect(result.type).toBe("ok");
    });
  });
});
