package ann;

import ann.activation.IActivationFunction;
import ann.activation.SigmoidActivationFunction;

public abstract class AbstractNeuron implements INeuron {
    public String name = "";
    public double output;
    public IActivationFunction activationFunction = new SigmoidActivationFunction();

    public AbstractNeuron(String name) {
        this.name = name;
    }

    public double getOutput() {
        return output;
    }

    public String getName() {
        return name;
    }

    @Override
    public String toString() {
        String result = name + ": ";
        result += "output: " + getOutput();
        return result;
    }

}
