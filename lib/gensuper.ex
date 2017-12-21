defmodule Gensuper do
      use GenServer   
      
         
    def start_link(name) do     

        nodeid=""       
        leafSet=[]
        rtable=[]
        hops=0
        numrequests=0
        neighbourhood_set=[]
        numnodecom=0
        pid_nodeID_map=%{}
        dest=0
        tothops=0
        numnodes=0
        GenServer.start_link(__MODULE__,{nodeid,numnodes,leafSet,rtable,neighbourhood_set,pid_nodeID_map,numrequests,numnodecom,hops, dest, tothops},name: via_tuple(name)) 
    end  

    def init(nodeid,numnodes,leafSet,rtable,neighbourhood_set,pid_nodeID_map,numrequests,numnodecom,hops,dest, tothops) do
         nodeid=""       
        leafSet=[]
        rtable=[]
        hops=0
        numrequests=0
        neighbourhood_set=[]
        numnodecom=0
        pid_nodeID_map=%{}
        dest=0
        tothops=0
        numnodes=0
        state =  {nodeid,numnodes,leafSet,rtable,neighbourhood_set,pid_nodeID_map,numrequests,numnodecom,hops,dest, tothops}
    {:ok, state}
   end

    def sendreq(numnodes,numnodecom,numrequests,server_pid) do
      key =""
      hop=0
      key = createNodeID(0, key)   
      if(numnodecom == numnodes )  do
            IO.puts "All peers have send out requests the required number of times"
      end      
       GenServer.cast(self(),{:routing,key,hop,server_pid})
       GenServer.cast(self(), {:update_numrequests, numnodecom,server_pid})
      
    end 

    def  createNodeID(i, nodeID_val) do                     #generate a random nodeID of 8 digits/ or a key to be send as message
    nodeID_val=
    if i < 8 do
      val = Integer.to_string(Enum.random(0..3))
      nodeID_val = nodeID_val <> val
      createNodeID(i+1, nodeID_val)
    else
      nodeID_val        
    end
    nodeID_val
  end

  def shl(key, nodeID, i) do
      i=
      if i<8 do
        if String.at(key, i) == String.at(nodeID, i) do
          shl(key, nodeID, i+1)
        else
          i
        end
      else
        i
      end
      i
end
#------------------------------------------implicit calls----------------------------------------------------------
  def via_tuple(room_name) do
   {:via, :gproc, {:n, :l, {:chat_room, room_name}}}
  end


   

#---------------------------------------------callbacks-------------------------------------------------------------

 def handle_cast({:init_node, nodeid,pid_nodeID_map, leaf,table,neigh,numRequests,numNodes,numnodecom,hops,dest,tothops}, state )do
       
        leafSet= leaf
        rtable=table
        neighbourhood_set= neigh
        numrequests=numRequests
        numnodes=numNodes
        #IO.puts "initializing pastry-----------------------------"
        state= {nodeid,numNodes,leafSet,rtable,neighbourhood_set,pid_nodeID_map,numrequests,numnodecom,hops,dest, tothops}
 {:noreply, state} 
end
 
def handle_cast({:initiate_routing,server_pid},state) do
      :timer.sleep(1)
      {nodeid,numnodes,leafSet,rtable,neighbourhood_set,pid_nodeID_map,numrequests,numnodecom,hops,dest, tothops} =state
      sendreq(numnodes,numnodecom,numrequests,server_pid)
      state= {nodeid,numnodes,leafSet,rtable,neighbourhood_set,pid_nodeID_map,numrequests,numnodecom,hops,dest, tothops}

     {:noreply, state}
end

def handle_cast({:update_numrequests,numnodecom1,server_pid},state)do
        :timer.sleep(1)
         {nodeid,numnodes,leafSet,rtable,neighbourhood_set,pid_nodeID_map,numrequests,numnodecom,hops,dest, tothops} =state
         numrequests=numrequests-1
        
        if numrequests >0 do
            sendreq(numrequests,numnodecom,numrequests,server_pid)                                 #change numrequests
        end
        state=  {nodeid,numnodes,leafSet,rtable,neighbourhood_set,pid_nodeID_map,numrequests,numnodecom,hops,dest, tothops}
    {:noreply,state}
end

def handle_cast({:routing, key, hop, server_pid}, state) do
        # Get th nodeID for self
         {nodeid,numnodes,leafSet,rtable,neighbourhood_set,pid_nodeID_map,numrequests,numnodecom,hops,dest, tothops} =state
        hops=hop
        min=0
        range=false
        matchnode="-1"
        
        leafSet_merge= Enum.at(leafSet,0) ++ Enum.at(leafSet,1)
       if (String.to_integer(Enum.at(leafSet_merge,0)) <= String.to_integer(key)  && String.to_integer(List.last(leafSet_merge))>=String.to_integer(key))do
                 min= abs(String.to_integer(List.last(leafSet_merge))-String.to_integer(key))
               #   IO.puts "------------inside leaf set----key:#{inspect key}------nodeid:#{inspect nodeid}----pid:#{inspect self()}--------"
                 node=Enum.each(leafSet_merge, fn (x)-> diff= abs(String.to_integer(key) - String.to_integer(x))
                                                             node=
                                                                 if diff < min do
                                                                    min=diff
                                                                    node=x
                                                                  node
                                                                  end                                                                
                                                            node
                                                            end)
            hops=hops+1            
            #IO.puts "--------------hop----#{hop}"
            GenServer.cast(server_pid,{:destination_reached,hops}) 
            
       else        
        #IO.puts "-----ELSE PART-------key:#{inspect key}------nodeid:#{inspect nodeid}----pid:#{inspect self()}----------"
          i=shl(key,nodeid, 0)
          #IO.puts "--------------------------i value #{i}--------------------------"
          col=String.to_integer(String.at(key,i))
          matchnode=rtable[i-1][col]                        #check i value
        #  IO.puts " Matchnode #{inspect matchnode}---key:#{inspect key}------nodeid:#{inspect nodeid}----pid:#{inspect self()}-"
          if(!(matchnode=="-1")) do
            hops=1+hops
          #  IO.puts "Matched and forwarding ------key:#{inspect key}------nodeid:#{inspect nodeid}----pid:#{inspect self()}"
            GenServer.cast( pid_nodeID_map[nodeid],{:routing,key,hops,server_pid})
          else   
          #   IO.puts "Did not match, check neighbourhood set"        
             rlist= Enum.reduce 0..7, [], fn x, row ->
                 row=Enum.reduce 0..3, row, fn y, colu ->   
                    value = rtable[x][y]
                    #IO.puts "Value is :#{value}"
                    if !(value=="-1" )do			
                        colu=[value|colu]
                    else
                        colu
                    end
              end 
            end 
            # IO.puts " Rlist #{inspect rlist} #{inspect self()}"
                tlist =Enum.at(leafSet,0) ++ Enum.at(leafSet,1)                 
                tlist =   rlist ++ tlist
                tlist = neighbourhood_set  ++ tlist
              #  IO.puts " Tlist--------#{inspect tlist} -#{inspect self()}"
    
                shl_l = shl(key,nodeid, 0)                  
                check=Enum.reduce 0..(length(tlist)-1), false,fn i,chk ->          
                    shl_T = shl(key,Enum.at(tlist,i), 0)
                    if((shl_T >= shl_l) and (abs(String.to_integer(Enum.at(tlist,i))-String.to_integer(key)) < abs(String.to_integer(nodeid)-String.to_integer(key)))) do
                        hops=1+hops 
                        GenServer.cast(pid_nodeID_map[Enum.at(tlist,i)],{:routing,key,hops,server_pid})
                        i=length(tlist)             #work around break
                        chk=true
                    end
                end
                if(!check) do
                
              #IO.puts "--------------hops----#{hops}"
                GenServer.cast(server_pid,{:destination_reached,hops}) 
                end 
            end 
        end 
        state= {nodeid,numnodes,leafSet,rtable,neighbourhood_set,pid_nodeID_map,numrequests,numnodecom,hops,dest,tothops}
        {:noreply,state}
        end

    def handle_cast({:destination_reached, hop}, state) do
        {nodeid,numnodes,leafSet,rtable,neighbourhood_set,pid_nodeID_map,numrequests,numnodecom,hops,dest,tothops} =state
        super_pid= :global.whereis_name(:server)
        dest = dest+1
        tothops = tothops + hop
        value = numnodes * numrequests
        IO.puts "Destination reached : #{dest}"   
        IO.puts "Total number of hops: #{tothops}"
        if dest == value do
            avg = tothops/value
            IO.puts "*********************************************************************"
            IO.puts "Number of Nodes     : #{numnodes}"
            IO.puts "Number of requests  : #{numrequests}"
            IO.puts "Average hops        : #{avg}"
            IO.puts "Destination reached : #{dest}"       
            Process.exit(super_pid,:kill)            
        end
        state= {nodeid,numnodes,leafSet,rtable,neighbourhood_set,pid_nodeID_map,numrequests,numnodecom,hops,dest,tothops} 
        {:noreply,state}
    end    

end
