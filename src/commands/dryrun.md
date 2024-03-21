# README for Command: .dryrun

### Syntax 

        .dryrun <flags> <{Tags}>

### Quick Examples

- Replacing the Send command with `.dryrun`:

        .dryrun ({ Target = 'FgU-RiEaLuC__SHZnI9pSIa_ZI8o-8hUVG9nPJvs92k', Action = 'Balance' })

or

- Using single word Action:

        .dryrun ({Balance}).

**Note:** 
- While using single words, the word inside the braces will be considered as Action ('Action'='Word'), and it takes your Process ID `ao.id` as both the Target and Process ID by default.
- Tags must be enclosed with curly braces `{}` surrounding the circle brackets with parentheses `()` is optional.



## Flags:
These flags determine the output you get on your terminal.

### TheFlags List:
- `-p` for specifying Process ID.
- `-d` for specifying data.
- `-r` for accessing the Result Object.
- `-v` for viewing the DryRun Parameterss

### Usage:
- Flags can be used in combinations, and the order of flags can be interchangeable.
- If you don't specify any flags, it will default to the `result object` (`-r`).
- If you don't specify a `-p` Process ID, your Process ID will be used.
- If you don't specify any `-d`, no data will be passed.




## Tags:
The tags that will be passed to perform DryRun.

### Usage:
- Tags must be enclosed with curly braces `{}`. Surrounding the circle brackets with parentheses `()` is optional.
- Single word tags must also be enclosed within curly braces `{}`.
- By default, the single word will be considered as Action. It takes your Process ID `ao.id` as both the Target and Process ID by default.

### Using 'ao.id'
Using "ao.id" to mention Process ID will work fine. By default Process ID and Target ID will be 'ao.id' (your process id). so its better to leave eit without mentioning it.  If you want to specify the "ao.id" word itself, then give it enclosed with a single quote enclosed with a double quote.

Samples :

    # to get ao.id

    .dryrun {'Balance'}

    .dryrun ({ Target = ao.id, Action = 'Balance' }) 

    .dryrun ({ Target = 'ao.id', Action = 'Balance' }) 

    # to get 'ao.id'

    .dryrun ({ Target = "'ao.id'", Action = 'Balance' }) 


## Examples:

- Replacing the Send command with `.dryrun` will give you the Result Object:

        .dryrun ({ Target = 'FgU-RiEaLuC__SHZnI9pSIa_ZI8o-8hUVG9nPJvs92k', Action = 'Balance' })

- Using Single word Action:

        .dryrun ({Balance})

  This will use "Balance" as Action and your Process ID as Target & Process ID:

        # .dryrun ({ Target = ao.id, Action = 'Balance' })

  **Sample Result Object Output:**

        {
        Messages: [
            {
            Target: '1234',
            Anchor: '00000000000000000000000000000917',
            Tags: [Array]
            }
        ],
        Spawns: [],
        Output: [],
        GasUsed: 466333831
        }

   This will give you the Result Overview. (More details will be available in the Message property.)


- Accessing the keys of the Result Object:

        .dryrun -r.Messages[0] ({Balance})

    This will give the Message Object of index=0 in Messages Array in the result object.

  Example Output:

        {
        Target: '1234',
        Anchor: '00000000000000000000000000000917',
        Tags: [
                { value: 'ao', name: 'Data-Protocol' },
                { value: 'ao.TN.1', name: 'Variant' },
                { value: 'Message', name: 'Type' },
                {
                value: 'FgU-RiEaLuC__SHZnI9pSIa_ZI8o-8hUVG9nPJvs92k',
                name: 'From-Process'
                },
                {
                value: '9afQ1PLf2mrshqCTZEzzJTR2gWaC9zNPnYgYEqg1Pt4',
                name: 'From-Module'
                },
                { value: '917', name: 'Ref_' },
                { value: '1e+14', name: 'Data' },
                { value: '1234', name: 'Target' },
                { value: 'PNTS', name: 'Ticker' },
                { value: '100000000000000', name: 'Balance' }
        ]
        }


- Sending data to the DryRun:

        .dryrun -d="test" ({Balance})

   or

        .dryrun -d="test" ({ Target = 'FgU-RiEaLuC__SHZnI9pSIa_ZI8o-8hUVG9nPJvs92k', Action = 'Balance' })

   or sending as Tag **(recommended method)**:

        .dryrun -d="test" ({ Target = 'FgU-RiEaLuC__SHZnI9pSIa_ZI8o-8hUVG9nPJvs92k', Action = 'Balance' , Data = 'test'})


- Passing Process ID:

        .dryrun -p="FgU-RiEaLuC__SHZnI9pSIa_ZI8o-8hUVG9nPJvs92k" ({Balance})


- Viewing DryRun Params :

        .dryrun -v {Message}

    Example Output : 

        dryrunParams: {
        process: 'FXYu2-c66N90yG2yqL0myafDgRTGONn0xn7xmZxEq7g',
        tags: [
            {
            name: 'Target',
            value: 'FXYu2-c66N90yG2yqL0myafDgRTGONn0xn7xmZxEq7g'
            },
            { name: 'Action', value: 'Message' }
        ]
        }

