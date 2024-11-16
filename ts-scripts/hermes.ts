const fetchLatestPriceUpdate = async (id: string) => {
    const url = `https://hermes.pyth.network/v2/updates/price/latest?ids%5B%5D=${id}`;

    const options = {
        method: "GET",
        headers: {
            accept: "application/json",
        },
    };
    let data: any;
    try {
        const response = await fetch(url, options);
        if (!response.ok) {
            throw new Error(`HTTP error! Status: ${response.status}`);
        }
        data = await response.json();
        // console.log(data);
    } catch (error) {
        console.error("error");
    }

    return data as {
        "binary": {
            "data": string[],
        }
    };
};

fetchLatestPriceUpdate('ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace').then((data) => {
    console.log(data.binary.data[0]);
});
