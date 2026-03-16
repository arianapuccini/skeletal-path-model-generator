using Pkg
# first time running the program, add all the packages below: Pkg.add("xxxxx")
using StructuralIdentifiability, SQLite, DBInterface, IterTools

# creates the SQL database
db = SQLite.DB("lcm.db")

# blue code is SQL code that creates the table with specified lables for columns
DBInterface.execute(db, """
CREATE TABLE IF NOT EXISTS results 
    (
    Vertices TEXT,
    Inputs TEXT,
    Outputs TEXT,
    Leaks TEXT,
    Globally_Identifiable TEXT,
    Locally_Identifiable TEXT,
    Nonidentifiable TEXT,
    Identifiable TEXT
    )
""")

# sorts compartments and flow rates by locally identifiable, globally identifiable, or unknown
function sortdata(parameters)
    coefficients = split(parameters, ", ")

    categories = Dict(
    :locally => String[],
    :globally => String[],
    :nonidentifiable => String[]
    )

    for c in coefficients
        name, type = split(c, " => ")
        push!(categories[Symbol(strip(type, ':'))], name)
    end

    locals  = join(categories[:locally], ", ")
    globals = join(categories[:globally], ", ")
    unknowns = join(categories[:nonidentifiable], ", ")

    findings = [locals, globals, unknowns]

    return findings

end

# generates skeletal graph models with all combinations of edges
function generate(vertices, i, graph, leak_subset)

    for combination in IterTools.subsets(collect(1:vertices))
        if (!(in(i, combination)))
            if (i != vertices)
                if (in(i+1, combination))
                    edges = collect(combination)
                    this_graph = copy(graph)
                    push!(this_graph, edges)
                else
                    continue
                end
            else
                edges = collect(combination)
                this_graph = copy(graph)
                push!(this_graph, edges)
            end
        else
            continue
        end

        if (i < vertices)
            generate(vertices, i + 1, this_graph, leak_subset)
        else
            addgraph(this_graph, vertices, leak_subset)
        end 
    end
end


# creates the linear compartmental model, assesses identifiability, and inserts information into the database
function addgraph(graph, vertices, leak_subset)
    # these specify which compartments have outputs, inputs, and leaks
    leak_location = isempty(leak_subset) ? "none" : join(leak_subset, ",")

    # creates the lcm
    lcm = linear_compartment_model(graph, outputs = [vertices], inputs = [1], leaks = leak_subset)

    # assesses identifiability and organizes parameters by locally identifiable, globally identifiable, and unidentifiable 
    result = string(assess_identifiability(lcm))
    parameters = result[findfirst('(', result)+1 : findlast(')', result)-1]
    findings = sortdata(parameters)
    locals = findings[1]
    globals = findings[2]
    unknowns = findings[3]

    # characterizes the model as identifiable or unidentifiable
    identifiable = !(occursin("nonidentifiable", result)) ? "yes" : "no"

    # puts data into the database
    DBInterface.execute(db, 
    "INSERT INTO results (Vertices, Inputs, Outputs, Leaks, Globally_Identifiable, Locally_Identifiable, Nonidentifiable, Identifiable) VALUES (?,?,?,?,?,?,?,?)", 
    (vertices, 1, vertices, leak_location, globals, locals, unknowns, identifiable))
    model_num[] += 1
    println("$(model_num[])")
end

# tests skeletal graphs with n vertices and all leak combinations
function tests(n)
    for vertices in 2:n
        leaks = collect(1:vertices)
        for k in 0:vertices
            for leak_subset in IterTools.subsets(leaks, k)
                graph = Vector{Vector{Int}}()
                generate(vertices, 1, graph, leak_subset)
            end
        end
    end
end                       
 
# calls the 'tests(n)' function to fill the database; then closes the database
model_num = Ref(0)
tests(3)
SQLite.close(db)