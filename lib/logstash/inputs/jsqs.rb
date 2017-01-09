# encoding: utf-8
# Original plugin by Al Belsky (https://logstash.jira.com/browse/LOGSTASH-1968)
require "logstash/inputs/threadable"
require "logstash/namespace"
require 'logstash-input-jsqs_jars.rb'

java_import "java.util.concurrent.Executors"
java_import "java.util.concurrent.atomic.AtomicInteger"
java_import "com.amazonaws.ClientConfiguration"
java_import "com.amazonaws.auth.profile.ProfileCredentialsProvider"
java_import "com.amazonaws.services.sqs.AmazonSQSAsyncClient"
java_import "com.amazonaws.services.sqs.buffered.AmazonSQSBufferedAsyncClient"
java_import "com.amazonaws.services.sqs.buffered.QueueBufferConfig"
java_import "com.amazonaws.services.sqs.model.ReceiveMessageRequest"
java_import "com.amazonaws.services.sqs.model.DeleteMessageBatchRequest"
java_import "com.amazonaws.services.sqs.model.DeleteMessageBatchRequestEntry"

class LogStash::Inputs::Jsqs < LogStash::Inputs::Threadable
  config_name "jsqs"

  # If undefined, Logstash will complain, even if codec is unused.
  default :codec, "json"

  # Name of the SQS Queue name to pull messages from. Note that this is just the name of the queue, not the URL or ARN.
  config :queueUrl, :validate => :string, :required => true
  config :max_connections, :validate => :number, :default => 1000
  config :max_batch_open_ms, :validate => :number, :default => 5000
  config :max_inflight_receive_batches, :validate => :number, :default => 50
  config :max_done_receive_batches, :validate => :number, :default => 50
  config :max_number_of_messages, :validate => :number, :default => 10
  config :retry_count, :validate => :number, :default => 5
  config :aws_profile, :validate => :string, :default => "default"

  @receiveRequest

  public
  def register
    @logger.info("Registering SQS input")

    # Client config
    @logger.debug("Creating AWS SQS queue client")
    clientConfig = ClientConfiguration.new.withMaxConnections(@max_connections)
    credentials = ProfileCredentialsProvider.new(@aws_profile)

    # SQS client
    @sqs = AmazonSQSAsyncClient.new(credentials, clientConfig)
    @logger.debug("Amazon SQS Client created")

    # Buffered client config
    queueBufferConfig = QueueBufferConfig.new.withMaxBatchOpenMs(@max_batch_open_ms).withMaxInflightReceiveBatches(@max_inflight_receive_batches).withMaxDoneReceiveBatches(@max_done_receive_batches)

    @bufferedSqs = AmazonSQSBufferedAsyncClient.new(@sqs, queueBufferConfig);
    @logger.info("Connected to AWS SQS queue successfully.", :queue => @queue)

    @receiveRequest = ReceiveMessageRequest.new(@queueUrl).withMaxNumberOfMessages(@max_number_of_messages)

  end # def register

  public
  def run(output_queue)
    @logger.debug("Polling SQS queue", :queue => @queue)

    while !stop?
      begin
        result = @bufferedSqs.receiveMessage(@receiveRequest)            
        deleteEntries = [] 
        # Process messages (expected 0 - 10 messages)
        result.messages.each_with_index { |message, i|
            @codec.decode(message.body) do |event|
                if event.is_a?(Array)
                    event.each do |msg|
                        decorate(msg)
                        output_queue << msg
                    end
                else
                    decorate(event)
                    output_queue << event
                end
            end # codec.decode
            
            #Add Delete entry for this message
            deleteEntries << DeleteMessageBatchRequestEntry.new.withId(i.to_s).withReceiptHandle(message.getReceiptHandle())
        }
        if deleteEntries.size > 0
            deleteRequest = DeleteMessageBatchRequest.new.withQueueUrl(@queueUrl);
            deleteRequest.setEntries(deleteEntries);
            # Issue delete request
            @bufferedSqs.deleteMessageBatch(deleteRequest);            
        end # end if
      rescue Exception => e
        if (@retry_count -= 1) > 0
          @logger.warn("Unable to access SQS queue. Sleeping before retrying.", :error => e.to_s, :queue => @queue)
          sleep(10)
          retry
        else
         @logger.error("Unable to access SQS queue. Aborting.", :error => e.to_s, :queue => @queue)
         stop
        end # if
      end # begin
    end # polling loop
  end # def run

  def stop
    @sqs = nil
    @bufferedSqs = nil
  end
end # class LogStash::Inputs::Jsqs
