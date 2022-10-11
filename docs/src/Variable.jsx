export default function Variable({ variable }) {
    console.log('variable', variable)
    const keys = ["constant", "visibility", "mutability"];
    return <div>
        <h2>{variable?.name}</h2>
        {variable?.functionSelector && <code>{variable?.functionSelector}</code>}
        <p style={{
            whiteSpace: 'pre-line'
        }}>{variable?.documentation?.text}</p>
        <h3>Metadata</h3>
        <table>
            <thead>
                <tr>
                    <th colspan="1">Type</th>
                    <th colspan="1">Value</th>
                </tr>
            </thead>
            <tbody>
                {keys.map(key => {
                    return <tr key={key}>
                        <th colspan="1" style={{
                            textTransform: "capitalize"
                        }}>{key}</th>
                        <th colspan="1" style={{
                            textTransform: "capitalize"
                        }}>{typeof (variable[key]) == "boolean" ? variable[key] == true ? 'True' : 'False' : variable[key]}</th>
                    </tr>
                })}
            </tbody>
        </table>
    </div>
}