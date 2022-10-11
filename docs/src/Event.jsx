export default function Event({ name, inputs }) {
    return <div>
        <h2>{name}</h2>
        <table>
            <thead>
                <tr>
                    <th colspan="1">Name</th>
                    <th colspan="1">Type</th>
                    <th colspan="1">Internal Type</th>
                    <th colspan="1">Indexed</th>
                </tr>
            </thead>
            <tbody>
                {inputs.map(input => <tr>
                    <td>{input.name}</td>
                    <td>{input.type}</td>
                    <td>{input.internalType}</td>
                    <td>{input.indexed ? 'True' : 'False'}</td>
                </tr>)}
            </tbody>
        </table>

    </div>
}