package
{
	import flash.events.AsyncErrorEvent;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.media.Camera;
	import flash.media.H264Level;
	import flash.media.H264Profile;
	import flash.media.H264VideoStreamSettings;
	import flash.media.Microphone;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	
	import spark.effects.CallAction;

	public class PublisherConnection extends NetConnection
	{
		protected var fcsPublisher:EncodeUtil = new EncodeUtil();
		protected var sessionKey:String = null;
		protected var password:String = null;
		protected var nsPublish : NetStream;
		
		protected var streamName:String;
		protected var publishMode:String;
		protected var camera:Camera;
		protected var microphone:Microphone;
		protected var h264:Boolean;
		
		protected var netStatus:Function;
		protected var netIOError:Function;
		protected var netASyncError:Function;
		
		public function PublisherConnection(username:String, password:String)
		{
			super();
			
			if(username.length && password.length)
			{
				this.sessionKey = "encoder:1.2.3.4:" + username;
				this.password = password;
			}
			
			this.client = this;
		}
		
		// add to support Akamai callback
		public function onClientLogin(data:Object):void
		{
			trace(data.description);
		}
		
		// add to support Akamai login callback
		public function setChallenge(sessionId:String, challenge:String):void
		{
			trace("sessionId: " + sessionId);
			sessionKey = sessionKey + ":" + sessionId;
			var password:String = fcsPublisher.hex_md5(challenge + ":" + this.password + fcsPublisher.hex_md5(sessionKey + ":" + challenge + ":" + this.password));
			call("ClientLogin", null, sessionKey, password);
		}
		
		public function onFCPublish(info:String) : void
		{
			trace("onFCPublish");
			publishStream();
		}
		
		public function onFCUnpublish(info:String) : void
		{
			trace("onFCUnpublish");
			stopPublish();
		}
		
		public function stopPublish() : void
		{
			nsPublish.close();
		}
		
		public function pausePublish() : void
		{
			nsPublish.pause();
		}
		
		public function resumePublish() : void
		{
			nsPublish.resume();
		}
		
		public function sendPublish(method:String, params:Object) : void
		{
			nsPublish.send("@setDataFrame", method, params);
		}
		
		public function publish(streamName:String, publishMode:String, camera:Camera, microphone:Microphone, h264:Boolean) : void
		{
			this.streamName = streamName;
			this.publishMode = publishMode;
			this.camera = camera;
			this.microphone = microphone;
			this.h264 = h264;
			
			if(sessionKey)
			{
				call("FCPublish", null, streamName, sessionKey);
			}
			else
			{
				publishStream();
			}
		}
		
		public function addDelegatedEventListener(type:String, callback:Function) : void
		{
			super.addEventListener(type, callback);
			
			switch(type)
			{
				case NetStatusEvent.NET_STATUS:
					netStatus = callback;
					break;
				
				case IOErrorEvent.IO_ERROR:
					netIOError = callback;
					break;
				
				case AsyncErrorEvent.ASYNC_ERROR:
					netASyncError = callback;
					break;
			}
		}
		
		private function publishStream() : void
		{
			var h264Settings:H264VideoStreamSettings = new H264VideoStreamSettings();
			h264Settings.setProfileLevel(H264Profile.BASELINE, H264Level.LEVEL_3_1);
			
			try 
			{
				// close previous stream
				if ( nsPublish != null ) 
				{
					trace("Publish stream stopped");
				}
				
				// Setup NetStream for publishing.
				nsPublish = new NetStream( this );
				
				if(h264)
					nsPublish.videoStreamSettings = h264Settings;
				
				nsPublish.addEventListener( NetStatusEvent.NET_STATUS, netStatus );
				nsPublish.addEventListener( IOErrorEvent.IO_ERROR, netIOError );
				nsPublish.addEventListener( AsyncErrorEvent.ASYNC_ERROR, netASyncError );
				nsPublish.client = this;
				
				// attach devices to NetStream.
				if ( camera != null ) 
				{
					nsPublish.attachCamera( camera );
				}
				if ( microphone != null) 
				{
					nsPublish.attachAudio( microphone );
				}
					
				nsPublish.publish( streamName, publishMode );
			}
			catch( e : ArgumentError ) 
			{
				switch ( e.errorID ) 
				{
					// NetStream object must be connected.
					case 2126 :
						trace( "Can't publish stream, not connected to server");
						break;
					default :
						trace( e.toString());
						break;
				}
			}
		}
	}
}