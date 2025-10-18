- [ ] Profile integration
- [ ] Add session state machine and reconilliation worker
- [x] connect to phoneix channels for streaming
- [x] use sonnar instead of phoneix flash messages
- [ ] default to chromium on arm64 systems ( mac with m1/m2/m3, linux arm64, etc )
- [x] Edge routing ( session/:id/edge/* should proxy to session host )
- [x] Add Auth System 
- [x] Add api tokens

- [ ] Webhook integration


- [ ] add session pool (system wide default pool and user defined pools)


- [] add /connect/ convience endpoint - uses default browser configurations
    - [ ] add ?token=  auth for this endpoint, (capability url so automation frameworks like puppeteer can use it)
    - [ ] add ?pool=  to select a pool of sessions to use
    - [ ] rename /sessions/:id/edge to /sessions/:id/connect and update all references to it
    - [ ]  


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



UX
- [ ] Add copy icon to new API token modal
- [ ] Fix account sign out everywhere button - it only signs out on the current device