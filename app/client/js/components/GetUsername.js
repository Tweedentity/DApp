import LoadingButton from './extras/LoadingButton'
import Basic from './Basic'

const {Panel, Grid, Row, Col, FormGroup, ControlLabel, FormControl, InputGroup, HelpBlock} = ReactBootstrap


class GetUsername extends Basic {
  constructor(props) {
    super(props)

    this.bindAll([
      'getValidationState',
      'handleChange',
      'getUserId'
    ])
  }

  getValidationState() {
    if (/^[a-zA-Z0-9_]{1,15}$/.test(this.getGlobalState('username'))) {
      return 'success'
    } else if (this.getGlobalState('username').length > 0) {
      return 'error'
    }
    return null
  }

  handleChange(e) {
    this.setGlobalState({username: e.target.value}, {err: null})
  }

  getUserId() {
    this.setGlobalState({}, {
      loading: true
    })
    return fetch(window.location.origin + `/api/user-id/${this.appNickname()}?r=` + Math.random(), {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        network: this.appState().netId,
        username: this.getGlobalState('username')
      }),
    })
      .then((response) => response.json())
      .then((responseJson) => {
        const r = responseJson.result

        if (r.sn) {
          this.setGlobalState({
            username: r.sn,
            userId: r.userId,
            name: r.name,
            avatar: r.avatar
          }, {
            loading: false
          })
          this.historyPush('userid-found')
        } else {
          throw(new Error('Not found'))
        }
      })
      .catch(err => {
        this.setGlobalState({}, {
          err: 'User not found',
          loading: false
        })
      })
  }

  render() {

    const as = this.appState()
    const wallet = as.wallet

    const state = as.data[this.shortWallet()]

    const appName = this.appName()

    return (
      <Grid>
        <Row>
          <Col md={12}>
            <h4 style={{padding: '0 15px 8px'}}>{appName} Username</h4>
            <Panel>
              <Panel.Body>

                <form>
                  <FormGroup
                    controlId="formBasicText"
                    validationState={as.err ? 'error' : this.getValidationState()}
                  >
                    <ControlLabel>Which is your {appName} Username?</ControlLabel>

                    <InputGroup>
                      <InputGroup.Addon>{as.config.decoration[this.appNickname()]}</InputGroup.Addon>
                      <FormControl
                        type="text"
                        value={state.value}
                        placeholder="Type username"
                        onChange={this.handleChange}
                      />
                      <FormControl.Feedback/>
                    </InputGroup>
                    {
                      as.err
                        ? <HelpBlock>{as.err}</HelpBlock>
                        : null
                    }
                  </FormGroup>
                </form>
                <LoadingButton
                  text={`Look up for ${appName} user-id`}
                  loadingText="Looking up"
                  loading={as.loading}
                  cmd={this.getUserId}
                  disabled={this.getValidationState() !== 'success'}
                />
              </Panel.Body>
            </Panel>
          </Col>
        </Row>
      </Grid>
    )
  }
}

export default GetUsername
