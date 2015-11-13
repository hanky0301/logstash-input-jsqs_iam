# encoding: utf-8
# Original plugin by Al Belsky (https://logstash.jira.com/browse/LOGSTASH-1968)

require "logstash/inputs/threadable"
require 'logstash-input-jsqs_jars.rb'

# Pull events from an Amazon Web Services Simple Queue Service (SQS) queue.
#
# SQS is a simple, scalable queue system that is part of the 
# Amazon Web Services suite of tools.
#
# Although SQS is similar to other queuing systems like AMQP, it
# uses a custom API and requires that you have an AWS account.
# See http://aws.amazon.com/sqs/ for more details on how SQS works,
# what the pricing schedule looks like and how to setup a queue.
#
# To use this plugin, you *must*:
#
#  * Have an AWS account
#  * Setup an SQS queue
#  * Create an identify that has access to consume messages from the queue.
#
# The "consumer" identity must have the following permissions on the queue:
#
#  * sqs:ChangeMessageVisibility
#  * sqs:ChangeMessageVisibilityBatch
#  * sqs:DeleteMessage
#  * sqs:DeleteMessageBatch
#  * sqs:GetQueueAttributes
#  * sqs:GetQueueUrl
#  * sqs:ListQueues
#  * sqs:ReceiveMessage
#
# Typically, you should setup an IAM policy, create a user and apply the IAM policy to the user.
# A sample policy is as follows:
#
#     {
#       "Statement": [
#         {
#           "Action": [
#             "sqs:ChangeMessageVisibility",
#             "sqs:ChangeMessageVisibilityBatch",
#             "sqs:GetQueueAttributes",
#             "sqs:GetQueueUrl",
#             "sqs:ListQueues",
#             "sqs:SendMessage",
#             "sqs:SendMessageBatch"
#           ],
#           "Effect": "Allow",
#           "Resource": [
#             "arn:aws:sqs:us-east-1:123456789012:Logstash"
#           ]
#         }
#       ]
#     } 
#
# See http://aws.amazon.com/iam/ for more details on setting up AWS identities.
#

class LogStash::Inputs::JSQS < LogStash::Inputs::Threadable

  config_name "jsqs"

  default :codec, "json"

  # Name of the SQS Queue name to pull messages from. Note that this is just the name of the queue, not the URL or ARN.
  config :queueUrl, :validate => :string, :required => true
  config :max_connections, :validate => :number, :default => 1000
  config :max_batch_open_ms, :validate => :number, :default => 5000
  config :max_inflight_receive_batches, :validate => :number, :default => 50
  config :max_done_receive_batches, :validate => :number, :default => 50
  config :max_number_of_messages, :validate => :number, :default => 10
  config :retry_count, :validate => :number, :default => 5

  @receiveRequest

  public
  def register
    @logger.info("Registering SQS input", :queue => @queue)

    # Client config
    @logger.debug("Creating AWS SQS queue client", :queue => @queue)
    clientConfig = ClientConfiguration.new.withMaxConnections(@max_connections)

    # SQS client
    @sqs = AmazonSQSAsyncClient.new(clientConfig)
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

    while running?   
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
         teardown
        end # if
      end # begin
    end # polling loop
  end # def run

  def teardown
    @sqs = nil
    @bufferedSqs = nil
    finished
  end # def teardown

end # class LogStash::Inputs::SQS
