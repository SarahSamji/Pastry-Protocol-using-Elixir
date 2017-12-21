defmodule Project3 do
  import Gensuper
   use Supervisor

  def main(argv) do
    arg = List.wrap(argv)

    numNodes = String.to_integer(List.first(arg))
    numRequests = String.to_integer(List.last(arg))
    IO.puts(numNodes)
    IO.puts(numRequests)
    start_link(numNodes,numRequests)
  end
  
  def start_link(numNodes,numRequests) do  
      {:ok,super_pid}= Supervisor.start_link(__MODULE__,[], name: :gossip_supervisor)  
      :global.register_name(:server,super_pid)   
      # super= :global.whereis_name(:server)
      # IO.puts "#{inspect super}" 
      pids= Enum.map(1..numNodes+1, fn(x) -> Supervisor.start_child(:gossip_supervisor, [x])end) 
      list_cpid=Enum.map(0..numNodes-1,fn(x)->({_,cpid}=Enum.at(pids,x)
                                                 cpid )end)
      #IO.inspect list_cpid
      {_, server_pid }=Enum.at(pids,numNodes)
      #IO.puts "#{inspect server_pid}"
      nodeID_val=""
      nodeID=[]      
                                         
      nodeID=for i<-0..numNodes-1 do
          temp = createNodeID(0, nodeID_val)
          #IO.puts(temp)
          nodeID = nodeID ++ temp
          nodeID
      end

      pid_nodeID_map=%{}
      pid_nodeID_map= create_pid_nodeidmap(numNodes,pid_nodeID_map,list_cpid,nodeID,0) 
     # IO.puts("Map-> #{inspect pid_nodeID_map}")


      nodeID_sorted = Enum.sort(nodeID)                                          #sorting the nodeID list
    #  IO.puts("sorted list ->#{inspect nodeID_sorted}")

      lower=[]
      higher=[]
      leafSet=[]
      init_map=%{}
      neighbourhood=[]
          
      len = length(nodeID)
      for i<-0..len-1 do   
          
         current_node= Enum.at(nodeID_sorted,i)
         {_,pid}=Map.fetch(pid_nodeID_map,current_node)  

          #---------Creating leaf set------------                               
          lower=
           if(i==0)do                                     
            lower=[]
            lower
          else
            lower=leafSet_lower(i, nodeID_sorted)
            lower
          end
          
          higher=leafSet_higher(i,nodeID_sorted, numNodes)
          leafSet= leafSet ++ [lower] ++ [higher]
         # IO.puts("leafSet of #{inspect pid} : #{inspect Enum.at(nodeID_sorted,i)} is--> #{inspect leafSet}")
          
          #-----------Creating Routing Table------------
      
          
          newnodeID=List.delete(nodeID_sorted,current_node)
          init_map= Enum.reduce 0..7, init_map, fn i, acc ->
                 Map.put(acc,i,%{0=>"-1",1=>"-1",2=>"-1",3=>"-1"})
                end
          rtable=routingTable(current_node, newnodeID, init_map, 0)
          
       #IO.puts("routing table --> #{inspect rtable}")

            
          #-----------Creating Neighbourhood Set--------
          neighbourhood_set=[]          
          neighbourhood_set=create_neighbourhood_set(newnodeID,neighbourhood_set,0)
          #IO.puts("neighborhood set --> #{inspect neighbourhood_set}")   

         # IO.puts " =----------PID #{inspect pid}"
          GenServer.cast(pid,{:init_node,current_node,pid_nodeID_map,leafSet,rtable,neighbourhood_set,numRequests,numNodes,0,0,0,0}) 
          #IO.puts "REURNINNG###################-------------------"

      end
        
     GenServer.cast(server_pid,{:init_node,"", %{},[],[],[],numRequests,numNodes,0,0,0,0})    
     for k <- 0..len-1 do
            node_pid = pid_nodeID_map[Enum.at(nodeID_sorted, k)]
            #IO.puts "About to start routing"
            GenServer.cast(node_pid, {:initiate_routing,server_pid})
     end 

      loop()
  end

 
  
  def leafSet_lower(index, nodeID_sorted) do
   leafSet_lower_list=  if index < 4 do
        low = 0
        high = index-1
        leafSet_lower_list = Enum.slice(nodeID_sorted, low..high)
        leafSet_lower_list
    else
        low = index-4
        high = index-1
        leafSet_lower_list = Enum.slice(nodeID_sorted, low..high)
        leafSet_lower_list
    end 
    leafSet_lower_list
  end

  def leafSet_higher(index, nodeID_sorted, numNodes) do
    if ((numNodes-index)==4) do
      low = index+1
      high = numNodes
      leafSet_higher_list = Enum.slice(nodeID_sorted, low..high)
    else
      low = index+1
      high = index+4
      leafSet_higher_list = Enum.slice(nodeID_sorted, low..high)
    end
    leafSet_higher_list
  end

  def create_pid_nodeidmap(numNodes,pid_nodeID_map,list_cpid,nodeID,i)do                #creating a map of nodeID and Pid
    
    pid_nodeID_map=
      if i < numNodes do
           pid_nodeID_map=Map.put(pid_nodeID_map,Enum.at(nodeID,i),Enum.at(list_cpid,i))
           create_pid_nodeidmap(numNodes,pid_nodeID_map,list_cpid,nodeID,i+1)           
      else
          pid_nodeID_map
      end
      pid_nodeID_map
  end


  def routingTable(current_node, newnodeID,init_map,count ) do
     
      init_map=
      if(count < length(newnodeID))do
          match_node=Enum.at(newnodeID,count) 
          init_map=find_pattern(0,current_node,match_node,init_map)          
          routingTable(current_node,newnodeID,init_map,count+1)
      else
       # IO.puts ("Else #{inspect init_map}")
        init_map
      end
     init_map
  end
  
  def find_pattern(i,current_node,match_node,init_map) do

      if i < 7 do      
              init_map=
              if String.slice(current_node,0..i) == String.slice(match_node,0..i) do
                    find_pattern(i+1, current_node,match_node,init_map)
              else
                 init_map=
                  if (i==0) do
                    init_map
                  else
                    init_map=
                      if String.slice(current_node,0..i-1) == String.slice(match_node,0..i-1) do
                          j=String.at(match_node,i)|>String.to_integer()   
                            init_map=
                                if (init_map[i][j]=="-1") do
                                  init_map=put_in init_map[i][j],match_node
                                  init_map
                                else
                                  init_map  
                                end   
                          init_map    
                      end         
                  init_map        
                end
                init_map               
              end        
                  init_map
      else
        init_map  
      end   
  end

   def create_neighbourhood_set( nodeID, neighbourhood_set,i) do
 
    neighbourhood_set=
    if i < 8 do
        temp = Enum.random(nodeID)      
       neighbourhood_set=
      if Enum.member?(neighbourhood_set,temp) do
        create_neighbourhood_set(nodeID,neighbourhood_set,i)
      else 
        neighbourhood_set = neighbourhood_set ++ [temp]
        create_neighbourhood_set(nodeID,neighbourhood_set,i+1)
        neighbourhood_set
      end
    else
      neighbourhood_set
    end
    neighbourhood_set
  end

  def loop do 
  #IO.puts " complete"
  loop()
  end

 def init(_) do
    children=[worker(Gensuper,[],restart: :temporary)]      
    supervise(children, strategy: :simple_one_for_one)
  end

end
