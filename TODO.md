- [ ] Profile integration
- [ ] Add session state machine and reconilliation worker
- [ ] default to chromium on arm64 systems ( mac with m1/m2/m3, linux arm64, etc )


- [ ] Webhook integration



-  [ ] allow connect endpoint to provision sessions from a pool if the pool is not at max capacity but no session is available ( ex. max 10 sessions, min 0 sessions, we would want to provision a session )
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
- [ ] 
- [ ] Deployment integration
- [ ] intercept cdp events and animate the ffmpeg webm stream sort of like a live action replay like https://screen.studio/
- [ ] match the stream output to the browser window size and aspect ratio, ensure the video frontend also handles any aspect ratio


- [ ] bug when we make a change the kind server sometimes just restarts and is slow to apply changes

UX
- [ ] Add copy icon to new API token modal
- [ ] Fix account sign out everywhere button - it only signs out on the current device

- [ ] BUG if we modify default browser pool it resets on server restart regardless of changes
- [ ] non admins should not be able to view or modify default browser pool or sessions - this should be a system level setting and not something defined per controller or context


- [ ] add realtime phoneix channel to pool page
- [ ]imporve interaction between idle shutdown and min ready, we wouldnt want all idle sessions to be removed if we are below the min ready threshold, we would want to keep the session thats ready to be culled until its replacement is ready