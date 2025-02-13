const express = require("express");
const basicAuth = require("express-basic-auth");

const app = express();
const port = 80;

const auth = basicAuth({
  users: {
    [process.env.USERNAME]: process.env.PASSWORD,
  },
  challenge: true,
});

app.get("/", (req, res) => {
  res.send("Hello, World!");
});

app.get("/secret", auth, (req, res) => {
  res.send(process.env.SECRET_MESSAGE);
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Server running on ${port}`);
});
