module.exports = {
  apps: [
    {
      name: "uart-api",
      script: "./api/server.js",
      env: {
        NODE_ENV: "production",
        PORT: 3000,
        // 리눅스 로컬에 설치될 MongoDB 기본 주소 (인증 없이 바로 접속)
        MONGO_URI: "mongodb://127.0.0.1:27017/uart"
      }
    },
    {
      name: "uart-crawler",
      script: "./crawler/main.py",
      interpreter: "python3",
      env: {
        MONGO_URI: "mongodb://127.0.0.1:27017/uart",
        KOPIS_API_KEY: "534331c08630453bbd1df50692635746",
        SMTP_USER: "dlfjs351@gmail.com",
        SMTP_PASS: "#gksrnrwpwl3A"
      }
    }
  ]
};
