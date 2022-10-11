export default function Function({ func }) {
    const keys = ['functionSelector', 'stateMutability', 'visibility']
    console.log('func', func)
    return <div>
        <h2>{func.name == "" && func.kind == "constructor" ? "constructor" : func.name}</h2>
        <p style={{
            whiteSpace: 'pre-line'
        }}>{func?.documentation?.text}</p>
        {func.kind != "constructor" && <div><h3>Metadata</h3>
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
                            <th colspan="1">{key}</th>
                            <th colspan="1">{func[key]}</th>
                        </tr>
                    })}
                </tbody>
            </table></div>}
        {func.parameters?.parameters.length != 0
            && <div>
                <h3>Parameters</h3>
                <table>
                    <thead>
                        <tr>
                            <th colspan="1">Name</th>
                            <th colspan="1">Type</th>
                        </tr>
                    </thead>
                    <tbody>
                        {func.parameters.parameters.map(params => <tr>
                            <td>{params.name}</td>
                            <td>{params?.typeDescriptions?.typeString}</td>
                        </tr>)}
                    </tbody>
                </table>
            </div>}
    </div>
}