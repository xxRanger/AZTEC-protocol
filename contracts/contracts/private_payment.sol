pragma solidity >=0.5.1 <= 0.6.2;

contract AZTEC {

    struct G1Point {
        uint x;
        uint y;
    }

    struct G2Point {
        uint[2] x;
        uint[2] y;
    }

    G1Point public h;
    //
    constructor () public {
        h = G1Point(17566712222922113045832476702662482910568538497722999586102925295983692901801,
            10502599197598057507557403467597036081442197834105478257107790310862497666839);
    }

    function FrExp2(uint base) view internal returns (uint) {
        uint r = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        // bytes32 r_bytes = bytes32(r);
        // bytes32 p_bytes = bytes32(uint(2));
        bytes memory input = abi.encodePacked(bytes32(uint(32)), bytes32(uint(32)), bytes32(uint(32)), bytes32(base), bytes32(uint(2)), bytes32(uint(r)));
        uint[1] memory result;
        uint gas_ = gasleft();
        bool success;
        assembly {
            success := staticcall(sub(gas_, 2000), 5, add(input, 0x20), 0xc0, result, 0x20)
        // Use "invalid" to make gas estimation work
            switch success case 0 {invalid()}
        }
        return result[0];
    }


    function G1() pure internal returns (G1Point memory) {
        return G1Point(1, 2);
    }

    function G2() pure internal returns (G2Point memory) {
        return G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
            10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
            8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
    }

    function T2() pure internal returns (G2Point memory) {
        return G2Point(
            [15550367399297628273624438287621380017282572154382051357698370679315571497817,
            12844800326064458347147611935234845946808492434262207421197939364988366441692],
            [1980405202821170546711664577257332226944093267916862049467402286356570294617,
            4999241324840461877046134530060071115217676474560883485092230926282487067324]);
    }

    function pairing(G1Point [] memory p1, G2Point[] memory p2) internal returns (bool) {
        require(p1.length == p2.length);
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].x;
            input[i * 6 + 1] = p1[i].y;
            input[i * 6 + 2] = p2[i].x[0];
            input[i * 6 + 3] = p2[i].x[1];
            input[i * 6 + 4] = p2[i].y[0];
            input[i * 6 + 5] = p2[i].y[1];
        }
        uint[1] memory out;
        bool success;
        assembly {
            success := call(sub(gas, 2000), 8, 0, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
        // Use "invalid" to make gas estimation work
            switch success case 0 {invalid()}
        }
        return out[0] != 0;
    }

    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }

    function check_pairing(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal returns (bool) {
        return pairingProd2(G1PointNegate(a1), a2, b1, b2);
    }


    function G1PointNegate(G1Point memory p) pure internal returns (G1Point memory) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.x == 0 && p.y == 0)
            return G1Point(0, 0);
        return G1Point(p.x, q - (p.y % q));
    }


    function G1PointAddition(G1Point memory p1, G1Point memory p2) internal returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.x;
        input[1] = p1.y;
        input[2] = p2.x;
        input[3] = p2.y;
        bool success;
        uint gas_ = gasleft();
        assembly {
            success := call(sub(gas_, 2000), 6, 0, input, 0x80, r, 0x40)
        // Use "invalid" to make gas estimation work
            switch success case 0 {invalid()}
        }
        require(success);
    }

    function G1PointScaleMul(G1Point memory p, uint s) internal returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.x;
        input[1] = p.y;
        input[2] = s;
        bool success;
        uint gas_ = gasleft();
        assembly {
            success := call(sub(gas_, 2000), 7, 0, input, 0x60, r, 0x40)
        // Use "invalid" to make gas estimation work
            switch success case 0 {invalid()}
        }
        require(success);
    }

    function FrAddition(uint x, uint y) pure internal returns (uint) {
        uint r = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        return (x + y) % r;
    }

    // use a*b = ((a+b)**2 - (a-b)**2)/4
    function FrMultiply(uint x, uint y) view internal returns (uint) {

        if (x < y) {
            uint tmp;
            tmp = x;
            x = y;
            y = tmp;
        }

        bool cond1 = false;
        bool cond2 = false;
        if ((x + y) % 2 != 0) {
            if (x % 2 == 1) {
                y = y + 1;
                cond1 = true;
            } else {
                x = x + 1;
                cond2 = true;
            }
        }

        uint xPlusy = (x + y) / 2;
        uint xMinusy = (x - y) / 2;
        uint xPlusyPow2 = FrExp2(xPlusy);
        uint xMinusyPow2 = FrExp2(xMinusy);
        uint res = FrAddition(xPlusyPow2, FrNegate(xMinusyPow2));

        if (cond1) {
            y -= 1;
            res = FrAddition(res, FrNegate(x));

        } else if (cond2) {
            x -= 1;
            res = FrAddition(res, FrNegate(y));

        }

        return res;
    }

    function FrNegate(uint x) pure internal returns (uint) {
        uint r = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        return r - x;
    }

    function load32bytes(uint256 addr) pure internal returns (uint){
        uint x;
        assembly {
            x := mload(addr)
        }
        return x;
    }

    function parseG1(bytes memory data) pure internal returns (G1Point [] memory){
        uint n = data.length / 64;
        G1Point [] memory g1 = new G1Point[](n);
        uint start = 0x20;
        for (uint i = 0; i < n; i++) {
            // parse gamma
            uint hpointer;
            assembly {
                hpointer := add(data, start)
            }
            g1[i].x = load32bytes(hpointer);
            hpointer += 0x20;
            g1[i].y = load32bytes(hpointer);
            start += 0x40;
        }
        return g1;
    }

    function parseFr(bytes memory data) pure internal returns (uint []memory) {
        uint n = data.length / 32;
        uint [] memory fr = new uint[](n);
        uint start = 0x20;
        for (uint i = 0; i < n; i++) {
            // parse gamma
            uint hpointer;
            assembly {
                hpointer := add(data, start)
            }
            fr[i] = load32bytes(hpointer);
            start += 0x20;
        }
        return fr;
    }

    function __verify_balance(G1Point [] memory gamma, G1Point []memory yita, uint m, uint k_public, uint c, uint [] memory a_, uint [] memory k_, uint n) internal returns (bool) {
        // calculate k1;
        uint k1_;
        if (m == 0) {
            for (uint i = 0; i < n - 1; i++) {
                k1_ = FrAddition(k1_, FrNegate(k_[i]));
            }
            k1_ = FrAddition(k1_, FrNegate(FrMultiply(k_public, c)));
        } else {
            for (uint i = m - 1; i < n - 1; i++) {
                k1_ = FrAddition(k1_, k_[i]);
            }
            for (uint i = 0; i < m - 1; i++) {
                k1_ = FrAddition(k1_, FrNegate(k_[i]));
            }
            k1_ = FrAddition(k1_, FrMultiply(k_public, c));
        }

        G1Point [] memory B = new G1Point[](n);
        for (uint i = 0; i < n; i++) {
            G1Point memory a_mul_h = G1PointScaleMul(h, a_[i]);
            G1Point memory c_mul_yita = G1PointScaleMul(yita[i], FrNegate(c));
            if (i == 0) {
                G1Point memory k1_mul_gamma = G1PointScaleMul(gamma[i], k1_);
                B[i] = G1PointAddition(G1PointAddition(k1_mul_gamma, a_mul_h), c_mul_yita);
                // B[i] = tmp;
            } else {
                G1Point memory k_mul_gamma = G1PointScaleMul(gamma[i], k_[i - 1]);
                B[i] = G1PointAddition(G1PointAddition(k_mul_gamma, a_mul_h), c_mul_yita);
            }
        }

        uint challenge = __calculate_challenge(gamma, yita, m, B);
        return challenge == c;

    }

    function __calculate_challenge(G1Point[] memory gamma, G1Point []memory yita, uint m, G1Point []memory B) internal returns (uint) {
        uint challenge_size = 64 * (gamma.length + yita.length + B.length) + 32;
        bytes memory packed_bytes = new bytes(challenge_size);
        uint n = gamma.length;
        uint start = 0x20;
        uint x;
        uint y;
        for (uint i = 0; i < n; i++) {
            x = gamma[i].x;
            assembly {
                mstore(add(packed_bytes, start), x)
            }

            y = gamma[i].y;
            assembly {
                mstore(add(packed_bytes, add(start, 0x20)), y)
            }
            x = yita[i].x;
            assembly {
                mstore(add(packed_bytes, add(start, 0x40)), x)
            }
            y = yita[i].y;
            assembly {
                mstore(add(packed_bytes, add(start, 0x60)), y)
            }
            start += 0x80;
        }

        assembly {
            mstore(add(packed_bytes, start), m)

        }
        start += 0x20;

        for (uint i = 0; i < n; i++) {
            x = B[i].x;
            assembly {
                mstore(add(packed_bytes, start), x)
            }
            y = B[i].y;
            assembly {
                mstore(add(packed_bytes, add(start, 0x20)), y)
            }
            start += 0x40;
        }

        bool success;
        uint gas_ = gasleft();
        uint[1]memory output;
        assembly {
            success := call(sub(gas_, 2000), 2, 0, add(packed_bytes, 0x20), challenge_size, output, 0x20)
        // Use "invalid" to make gas estimation work
            switch success case 0 {invalid()}
        }

        uint r = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        return output[0] % r;
    }

    function __calculate_challenge_x(G1Point []memory gamma, G1Point[]memory yita) internal returns (uint){
        uint challenge_size = 64 * (gamma.length + yita.length);
        bytes memory packed_bytes = new bytes(challenge_size);
        uint n = gamma.length;
        uint start = 0x20;
        uint x;
        uint y;
        for (uint i = 0; i < n; i++) {
            x = gamma[i].x;
            assembly {
                mstore(add(packed_bytes, start), x)
            }

            y = gamma[i].y;
            assembly {
                mstore(add(packed_bytes, add(start, 0x20)), y)
            }
            x = yita[i].x;
            assembly {
                mstore(add(packed_bytes, add(start, 0x40)), x)
            }
            y = yita[i].y;
            assembly {
                mstore(add(packed_bytes, add(start, 0x60)), y)
            }
            start += 0x80;
        }

        bool success;
        uint gas_ = gasleft();
        uint[1]memory output;
        assembly {
            success := call(sub(gas_, 2000), 2, 0, add(packed_bytes, 0x20), challenge_size, output, 0x20)
        // Use "invalid" to make gas estimation work
            switch success case 0 {invalid()}
        }
        uint r = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        return output[0] % r;
    }

    function __verify_pairing(G1Point[] memory gamma, G1Point[] memory yita, uint m, uint n, uint c, bool move_out) internal returns (bool) {
        if (move_out) {
            if (m == n) return true;
            G1Point memory assemble_gamma;
            G1Point memory assemble_yita;
            uint x = __calculate_challenge_x(gamma, yita);
            for (uint i = m; i < n; i++) {

                G1Point memory _gamma = gamma[i];
                G1Point memory _yita = yita[i];
                if (i == m) {
                    assemble_gamma = _gamma;
                    assemble_yita = _yita;
                } else {
                    uint fr = FrMultiply(FrMultiply(x, i), c);
                    assemble_gamma = G1PointAddition(assemble_gamma, G1PointScaleMul(_gamma, fr));
                    assemble_yita = G1PointAddition(assemble_yita, G1PointScaleMul(_yita, fr));
                }
            }

            return check_pairing(assemble_gamma, T2(), assemble_yita, G2());
        } else {
            if (m == 0) return true;
            G1Point memory assemble_gamma;
            G1Point memory assemble_yita;
            uint x = __calculate_challenge_x(gamma, yita);
            for (uint i = 0; i < m; i++) {
                G1Point memory _gamma = gamma[i];
                G1Point memory _yita = yita[i];
                if (i == m) {
                    assemble_gamma = _gamma;
                    assemble_yita = _yita;
                } else {
                    uint fr = FrMultiply(FrMultiply(x, i), c);
                    assemble_gamma = G1PointAddition(assemble_gamma, G1PointScaleMul(_gamma, fr));
                    assemble_yita = G1PointAddition(assemble_yita, G1PointScaleMul(_yita, fr));
                }
            }
            return check_pairing(assemble_gamma, T2(), assemble_yita, G2());
        }
    }


    function verify(bytes memory gamma_byte, bytes memory yita_byte, uint m, uint k_public, uint c, bytes memory a_bytes, bytes memory k_bytes, uint n, bool move_out) internal {
        require(gamma_byte.length == n * 64, "gamma length not qualify");
        require(yita_byte.length == n * 64, "yita length not qualify");
        require(a_bytes.length == n * 32, "a_ length not qualify");
        require(k_bytes.length == (n - 1) * 32, "k_ length not qualify");
        G1Point []memory gamma = parseG1(gamma_byte);
        //

        G1Point []memory yita = parseG1(yita_byte);
        uint [] memory a_ = parseFr(a_bytes);
        uint [] memory k_ = parseFr(k_bytes);

        // verify pariing
        require(__verify_pairing(gamma, yita, m, n, c, move_out));

        // verify balance

        require(__verify_balance(gamma, yita, m, k_public, c, a_, k_, n));


    }

    function verify_move_in(bytes memory gamma_byte, bytes memory yita_byte, uint m, uint k_public, uint c, bytes memory a_bytes, bytes memory k_bytes, uint n) public {
        verify(gamma_byte, yita_byte, m, k_public, c, a_bytes, k_bytes, n, false);
    }

    function verify_move_out(bytes memory gamma_byte, bytes memory yita_byte, uint m, uint k_public, uint c, bytes memory a_bytes, bytes memory k_bytes, uint n) public {
        verify(gamma_byte, yita_byte, m, k_public, c, a_bytes, k_bytes, n, true);
    }

    function test() public {
        
    }
}