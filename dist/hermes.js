"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
const fetchLatestPriceUpdate = (id) => __awaiter(void 0, void 0, void 0, function* () {
    const url = `https://hermes.pyth.network/v2/updates/price/latest?ids%5B%5D=${id}`;
    const options = {
        method: "GET",
        headers: {
            accept: "application/json",
        },
    };
    let data;
    try {
        const response = yield fetch(url, options);
        if (!response.ok) {
            throw new Error(`HTTP error! Status: ${response.status}`);
        }
        data = yield response.json();
        // console.log(data);
    }
    catch (error) {
        console.error("error");
    }
    return data;
});
fetchLatestPriceUpdate('ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace').then((data) => {
    console.log(data.binary.data[0]);
});
