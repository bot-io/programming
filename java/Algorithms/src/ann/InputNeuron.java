package ann;

public class InputNeuron extends AbstractNeuron {

    public InputNeuron(String name) {
        super(name);
    }

    public double input;


    @Override
    public double activate() {
        return input;
    }

    @Override
    public double getOutput() {
        return input;
    }

    public void setInput(double input) {
        this.input = input;
    }
}
