- [ ] Profile integration
- [ ] Add session state machine and reconilliation worker
- [x] connect to phoneix channels for streaming
- [x] use sonnar instead of phoneix flash messages
- [ ] default to chromium on arm64 systems ( mac with m1/m2/m3, linux arm64, etc )
- [x] Edge routing ( session/:id/connect/* should proxy to session host )
- [x] Add Auth System 
- [x] Add api tokens

- [ ] Webhook integration


- [x] add session pool (system wide default pool and user defined pools)

- [ ] add ?token= auth support for all api endpoints
- [x] add authorized user check plug to all api endpoints see below
- [x] rename /sessions/:id/edge to /sessions/:id/connect and update all references to it
    - [x] add api/sessions/:id/connect endpoint aswell 

- [] add api/v1/connect/ convience endpoint - uses default pool of sessions ( connect endpoint immediately returns proxied details to a session, claim stuff happens automatically in the background) 

example: https://browsergrid.com/connect/json?token=... 
returns: 
{
  "Browser": "Chrome/141.0.7390.107",
  "Protocol-Version": "1.3",
  "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36",
  "V8-Version": "14.1.146.11",
  "WebKit-Version": "537.36 (@1c008349f76ff3a317bf28316fc5008c0120deb4)",
  "devtoolsFrontendUrl": "ws://browsergrid.com/session/:id/connect/devtools/browser/fd033ce1-f5ce-4fba-b9c0-99539fedec53",
  "webSocketDebuggerUrl": "ws://browsergrid.com/session/:id/connect/devtools/browser/fd033ce1-f5ce-4fba-b9c0-99539fedec53"
}

    - [ ] add optional ?pool=  to select a pool of sessions to use


- [ ] adding CUA endpoint for browser
    - [ ] add visual ( similar to chatgpt where we should a  rendering  similar to this https://screen.studio/?aff=Yy75o )
    - [ ] chat  (jido agents?)
    - Note: our chat feature will likely need to use pooled sessions for fast acquisition and efficient use of resources
    - we wouldnt want to constinantly cycle through sessions in a chat like evironment where user requests are frequent
    - we would need to figure out how to handle the session lifecycle in a chat like environment
    - we would want to keep the user browser state active and wouldnt want to charge users for the idle time between chat messages
      - ex. message 1: user asks for a visit a website, 10 minutes later message 2: user asks to do an action this page. 
      - do we charge for the 10 minutes of idle time?
      - would we create a profile for each chat and keep that profile hot swaping it into an available node each time the user sends a message?
      - would it be possible to restore the near exact state of the browser from the previous message?
      -maybe add a flag for persistant chat browser sessions and warn users that they will be charged for the idle time between messages while the chat window is open
- [ ] test to see if we can test 1 million sessions ( fake pods/containers) 

- [ ] Deployment integration
- [ ] intercept cdp events and animate the ffmpeg webm stream sort of like a live action replay like https://screen.studio/
- [ ] match the stream output to the browser window size and aspect ratio, ensure the video frontend also handles any aspect ratio


- [ ] bug when we make a change the kind server sometimes just restarts and is slow to apply changes
UX
- [ ] Add copy icon to new API token modal
- [ ] Fix account sign out everywhere button - it only signs out on the current device

- [ ] BUG if we modify default browser pool it resets on server restart regardless of changes
- [ ] non admins should not be able to view or modify default browser pool or sessions - this should be a system level setting and not something defined per controller or context
- [ ] non admins can claim sessions from the default pool
- [ ] non admins should only see sessions they have claimed or are associated with in their session list
- [ ] non admins should only be able to view their own related resources


- [ ] update pool params to be like this:
  "min": 0,
  "max": 10,
  "max_concurrency": 5,
  "timeout_minutes": 30