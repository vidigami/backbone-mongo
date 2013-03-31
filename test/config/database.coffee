module.exports =
  test:
    host: process.env.DBHOST || 'localhost'
    port: parseInt(process.env.DBPORT, 10) || 27017
    user: process.env.DBUSER || ''
    password: process.env.DBPASSWORD || ''
    database: process.env.DBNAME || 'test-mongo-backbone'