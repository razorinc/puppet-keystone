require 'rest-client'

module Keystonerest
  extend self

  def authenticate(username,password,tenantName)
    retry_limit=3
    retry_counter=0
    
    credentials={:auth=>
      {:passwordCredentials=>
        {:username=>username,
          :password=>password
        },
        :tenantName=>tenantName } }.to_json
    begin
      @output=RestClient.post('/tokens', credentials,
                             {:content_type => :json,
                               :accept      => :json})
      @output_h = JSON.parse(@output)
      @token = @output_h["access"]["token"]
      @services = @output_h["access"]["serviceCatalog"]
      @user = @output_h["access"]["user"]

    rescue Errno::EHOSTUNREACH
      retry_counter+=1
      retry if retry_counter<retry_limit
      # After the retries, die.
      Puppet::Error("Connection Broken")
    rescue Errno::ECONNREFUSED
      Puppet::Error("Connection Broken")
    rescue Exception => e
      e.message
    end
  end

  def with_verify_token(&block)
    if valid_token?
      block.call
    else
      Puppet::Error("Error")
    end
  end

  def list_keystone_objects(type)
    send 'list_keystone_object_l#{type}'
  end


  def get_keystone_object(type,id,attr)
    send 'get_keystone_object_#{type}' id,attr
  end


  def get_keystone_object_service

  end

  def get_keystone_object_user(id,attr)
    safely do
      @user = RestClient.get('/users/#{id}',
                             {:content_type  => :json,
                               :accept       => :json,
                               "X-Auth-Token"=> @token["id"] })
    end
    @user['user'][attr]
  end

  def get_keystone_object_tenant(id,attr)
    safely do
      @tenant = RestClient.get('/tenants/#{id}', 
                               {:content_type  => :json,
                                 :accept       => :json,
                                 "X-Auth-Token"=> @token["id"] })
    end
    @tenant[attr]
  end

  def list_keystone_object_services
    with_verify_token {
      @services.select{|element| element["name"]==type}
    }
  end

  def list_keystone_object_role
    with_verify_token {
      safely do
        @output = RestClient.get('/OS-KSADM/roles',  
                                 {:content_type=>:json, 
                                   :accept=>:json, 
                                   :"X-Auth-Token"=> @token["id"] })
    }
  end
  
  def list_keystone_object_services
    with_verify_token do
      safely do
        @output = RestClient.get '/OS-KSADM/services',  
        {:content_type=>:json, :accept=>:json, "X-Auth-Token"=> @token["id"] }
      end
    end
  end

  private do
    attr_accessor :token, :services, :user, :roles

    def valid_token?
      # Authenticate if @token.nil
      authenticate if @token.nil?
      time_diff = ((Time.parse(@token["expires"])-Time.now)/60).to_i  
      time_diff >0 ? true: false
    end
  
    def safely(&block)
      with_verify_token {
        retry_limit=3
        retry_counter=0
        begin
          yield
        rescue Errno::EHOSTUNREACH
          retry_counter+=1
          retry if retry_counter<retry_limit
          # After the retries, die.
          Puppet::Error("Connection Broken")
        rescue Errno::ECONNREFUSED
          Puppet::Error("Connection Broken")
        rescue Exception => e
          e.message
        end
      }
    end


end
