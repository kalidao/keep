export default function Event({ event }) {
    console.log('event params', event)
    return <div>
        <h2>{event?.name}</h2>
        <p style={{
            whiteSpace: 'pre-line'
        }}>{event?.documentation?.text}</p>
        <table>
            <thead>
                <tr>
                    <th colspan="1">Name</th>
                    <th colspan="1">Type</th>
                    <th colspan="1">Indexed</th>
                </tr>
            </thead>
            <tbody>
                {event?.parameters?.parameters?.map(param => <tr>
                    <td>{param.name}</td>
                    <td>{param.typeDescriptions.typeString}</td>
                    <td>{param.indexed ? 'True' : 'False'}</td>
                </tr>)}
            </tbody>
        </table>

    </div>
}