'use strict'

const superagent = require('superagent')
const ethUtil = require('ethereumjs-util')
const cheerio = require('cheerio')
const serverless = require('serverless-http')
const path = require('path')

const express = require('express')
const app = express()

const utils = require('./lib/Utils')
const db = require('./lib/db')

app.use(express.static(path.join(__dirname, 'public')))

app.get('/', (req, res) => {
  res.send('Welcome to the Tweedentity API')
})

app.get('/twitter/:userId', (req, res) => {

  db.get(`${req.params.userId}@1`, (error, result) => {
    if (error) {
      console.log('Error:', error)
      res.status(400).json(error)
    } else {
      res.jsonp(result)
    }
  })
})

app.get('/twitter/:id/:address', (req, res) => {

  function respond(err, val) {
    if (err) console.log('Error', err)
    res.send(val || err)
  }

  const {id, address} = req.params

  if (id && /^\d{18,20}$/.test(id) && /^0x[0-9a-fA-F]{40}$/.test(address)) {

    superagent
        .get(`https://twitter.com/twitter/status/${id}`)
        .then(post => {

          if (post.text) {
            const $ = cheerio.load(post.text)

            const dataTweet = $('div[data-tweet-id="' + id + '"]')
            const userId = dataTweet.attr('data-user-id')
            const screenName = dataTweet.attr('data-screen-name')
            const name = dataTweet.attr('data-name')

            const data = utils.deconstructSignature($('meta[property="og:description"]').attr('content'))

            const {shortAddr, message, sig, signer, signame, version} = data

            if (version === '1' && RegExp(`^${shortAddr}`, 'i').test(address) && /^\w+$/.test(userId) && message === `twitter/${userId}` && /^0x[0-9a-f]{130}/.test(sig)) {

              if (utils.verify(address, message, sig, signer, signame)) {
                const lastUpdate = Math.round(Date.now() / 1000)
                db.put(`${userId}@1`, screenName, name, address, lastUpdate, (err) => {
                  if (err) {
                    console.log('Error')
                  }
                  respond(null, userId)
                })
              } else respond('wrong-sig') // wrong utils
            } else respond('wrong-post') // wrong tweet

          } else respond('no-tweet') // no tweet
        })
        .catch((err) => {
          console.log('Error')
          respond('catch-error')
        })
  } else {
    respond('wrong-pars')
  }

})


app.get('/reddit/:userId', (req, res) => {

  console.log('${req.params.userId}@2', `${req.params.userId}@2`)
  db.get(`${req.params.userId}@2`, (error, result) => {
    if (error) {
      console.log('Error:', error)
      res.status(400).json(error)
    } else {
      res.jsonp(result)
    }
  })
})



app.get('/reddit/:id/:address', (req, res) => {

  function respond(err, val) {
    if (err) console.log('Error', err)
    res.send(val || err)
  }

  const {id, address} = req.params

  if (id && /^[a-z0-9_]{8,12}$/.test(id) && /^0x[0-9a-fA-F]{40}$/.test(address)) {

    superagent
        .get(`https://www.reddit.com/api/info.json?id=${id}`)
        .set('Accept', 'application/json')
        .then(result => {

          let userData = result.body

          if (userData.error) {
            throw(respond('wrong-post'))

          } else if (userData.data && Array.isArray(userData.data.children)) {

            for (let elem of userData.data.children) {

              if (
                  elem.data
                  && elem.data.body
              ) {
                let username = elem.data.author.toLowerCase()

                let {shortAddr, message, sig, signer, signame, version} =
                    utils.deconstructSignature(elem.data.body.split(' ')[0])

                if (version === '1' && RegExp(`^${shortAddr}`, 'i').test(address) && message === `reddit/${elem.data.author}` && /^0x[0-9a-f]{130}/.test(sig)) {

                  if (utils.verify(address, message, sig, signer, signame)) {
                    const lastUpdate = Math.round(Date.now() / 1000)

                    console.log('${username}@2', `${username}@2`)
                    db.put(`${username}@2`, elem.data.author, '', address, lastUpdate, (err) => {
                      respond(null, username)
                    })
                  } else respond('wrong-sig') // wrong utils
                } else respond('wrong-post') // wrong tweet
              }
            }
          } else respond('wrong-post')
        })
        .catch((err) => {
          console.log('Error')
          respond('catch-error')
        })
  } else {
    respond('wrong-pars')
  }

})


app.use((req, res) => res.sendStatus(404))

exports.app = app
exports.handler = serverless(app)
