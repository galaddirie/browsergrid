- [ ] Complete Profile integration
- [ ] Complete Deployment integration

- [ ] Add Webhook integration


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
- [ ] add a chaos engineering test suite
- [ ] intercept cdp events and animate the ffmpeg webm stream sort of like a live action replay like https://screen.studio/
- [ ] match the stream output to the browser window size and aspect ratio, ensure the video frontend also handles any aspect ratio


- [ ] bug when we make a change the kind server sometimes just restarts and is slow to apply changes

UX
- [ ] Add copy icon to new API token modal




- [ ] imporve interaction between idle shutdown and min ready, we wouldnt want all idle sessions to be removed if we are below the min ready threshold, we would want to keep the session thats ready to be culled until its replacement is ready


- [ ] use libcluster + horde + k8 for a sepreate server to scale websocket connections and websocket clusters  ex. ws://connect.browsergrid.io - make it easy to self host (auto dns?)

- [ ] improve websocket scale - study where we are bottlenecked and improve it 

- [ ] remove polling with K8s watchers (real-time events) to reduce API calls.

review - does it make sense to distrubute session actors across multiple nodes?

how do we distrubute the phoneix api


BUG- when we spin up a session pod where the api is unreachable we mark the session as an error but keep the pod running


BUG: if we have one node down and we spin up a session, if the node goes down the session pod stays up, when the node comes back up we cant connect to the session pod via node/session/:id/connect we get session not running error

Test multi node deployment, create task utils to delete nodes and pods and see how the session runtime and actors behaves with a multi node deployment